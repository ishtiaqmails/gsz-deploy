'use strict';
/* WhatsApp notification outbox worker (Phase 2d).
   Polls wa_notifications for QUEUED rows, renders the template, resolves the
   recipient (captured PN -> profile number -> LID jid), and posts to the bot's
   send API. Retries transient failures with backoff, caps attempts, and is
   idempotent (unique idempotency_key on enqueue). Never crashes the app. */
const http = require('http');
const https = require('https');
const { URL } = require('url');

module.exports = function (pool) {
  async function settings() { const r = await pool.query('SELECT key,value FROM wa_settings'); const o = {}; r.rows.forEach(x => o[x.key] = x.value); return o; }
  async function tpl(key) { const r = await pool.query('SELECT body FROM wa_templates WHERE key=$1', [key]); return r.rows[0] ? r.rows[0].body : ''; }
  function render(body, vars) { return String(body || '').replace(/\{\{(\w+)\}\}/g, (_, k) => (vars && vars[k] != null) ? String(vars[k]) : ''); }

  function postSend(sendUrl, secret, payload) {
    return new Promise(resolve => {
      try {
        const u = new URL(sendUrl);
        const data = Buffer.from(JSON.stringify(payload));
        const mod = u.protocol === 'https:' ? https : http;
        const r = mod.request({
          hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80),
          path: u.pathname + u.search, method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Content-Length': data.length, 'X-WA-Secret': secret }
        }, res => { let b = ''; res.on('data', d => b += d); res.on('end', () => { let j = null; try { j = JSON.parse(b); } catch (e) {} resolve({ status: res.statusCode, body: j }); }); });
        r.on('error', e => resolve({ status: 0, error: e.message }));
        r.setTimeout(12000, () => { try { r.destroy(); } catch (e) {} resolve({ status: 0, error: 'timeout' }); });
        r.write(data); r.end();
      } catch (e) { resolve({ status: 0, error: e.message }); }
    });
  }

  async function resolveRecipient(n) {
    if (n.destination_phone) return n.destination_phone;
    if (n.destination_identity_id) {
      const i = (await pool.query('SELECT current_phone_e164, canonical_lid FROM whatsapp_identities WHERE id=$1', [n.destination_identity_id])).rows[0];
      if (i && i.current_phone_e164) return i.current_phone_e164;
    }
    if (n.customer_id) {
      const c = (await pool.query('SELECT wa_number FROM customers WHERE id=$1', [n.customer_id])).rows[0];
      if (c && c.wa_number) return c.wa_number;
    }
    if (n.destination_identity_id) {
      const i = (await pool.query('SELECT canonical_lid FROM whatsapp_identities WHERE id=$1', [n.destination_identity_id])).rows[0];
      if (i && i.canonical_lid) return i.canonical_lid + '@lid';   // last resort: message the LID directly
    }
    return null;
  }

  async function tick() {
    let s;
    try { s = await settings(); } catch (e) { return; }
    if (s.wa_notifications_enabled === '0') return;
    const sendUrl = s.wa_bot_send_url, secret = s.wa_bot_webhook_secret;
    if (!sendUrl || !secret) return;
    let claimed = [];
    try {
      claimed = (await pool.query(
        "UPDATE wa_notifications SET status='SENDING' WHERE id IN (SELECT id FROM wa_notifications WHERE status='QUEUED' AND next_attempt_at <= now() ORDER BY queued_at LIMIT 5 FOR UPDATE SKIP LOCKED) RETURNING *")).rows;
    } catch (e) { return; }
    for (const n of claimed) {
      try {
        const to = await resolveRecipient(n);
        if (!to) { await pool.query("UPDATE wa_notifications SET status='FAILED', failed_at=now(), last_error='no recipient' WHERE id=$1", [n.id]); continue; }
        const vars = Object.assign({}, n.vars || {});
        if (vars.sales_number == null) vars.sales_number = s.wa_sales_number || '';
        if (vars.support_number == null) vars.support_number = s.wa_support_number || '';
        const text = render(await tpl(n.template_key), vars) || ('(' + n.template_key + ')');
        const r = await postSend(sendUrl, secret, { to, text });
        if (r.status === 200 && r.body && r.body.ok) {
          await pool.query("UPDATE wa_notifications SET status='SENT', sent_at=now(), provider_message_id=$2 WHERE id=$1", [n.id, (r.body.id || null)]);
        } else {
          const att = (n.attempts || 0) + 1;
          const err = (r.body && r.body.error) || r.error || ('http ' + r.status);
          if (att >= 5) await pool.query("UPDATE wa_notifications SET status='FAILED', failed_at=now(), attempts=$2, last_error=$3 WHERE id=$1", [n.id, att, err]);
          else await pool.query("UPDATE wa_notifications SET status='QUEUED', attempts=$2, last_error=$3, next_attempt_at=now() + ($4||' seconds')::interval WHERE id=$1", [n.id, att, err, String(att * 30)]);
        }
      } catch (e) {
        try {
          const att = (n.attempts || 0) + 1;
          await pool.query("UPDATE wa_notifications SET status=CASE WHEN $2>=5 THEN 'FAILED' ELSE 'QUEUED' END, attempts=$2, last_error=$3, next_attempt_at=now() + ($4||' seconds')::interval, failed_at=CASE WHEN $2>=5 THEN now() ELSE failed_at END WHERE id=$1", [n.id, att, String(e.message), String(att * 30)]);
        } catch (_) {}
      }
    }
  }

  function startWorker() {
    const iv = parseInt(process.env.WA_WORKER_INTERVAL_MS || '10000', 10);
    setInterval(() => { tick().catch(() => {}); }, iv);
    console.log('[wanotify] outbox worker started (every ' + iv + 'ms)');
  }

  // Helper for other modules to queue a notification.
  async function enqueue(o) {
    return pool.query(
      "INSERT INTO wa_notifications(customer_id,order_id,destination_identity_id,destination_phone,template_key,vars,idempotency_key) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING",
      [o.customer_id || null, o.order_id || null, o.destination_identity_id || null, o.destination_phone || null, o.template_key, JSON.stringify(o.vars || {}), o.idempotency_key || null]);
  }

  return { startWorker, enqueue, tick };
};
