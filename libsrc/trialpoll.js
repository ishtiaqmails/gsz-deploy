'use strict';
/* Trial poller — Phase 4b (async). Polls the bot's /api/trial-status for
   'pending' trial_claims (two-step generation), stores credentials when ready,
   and delivers them via the WhatsApp outbox + email. Self-healing: if the
   status GET fails, it re-POSTs generate-trial (idempotent on request_id).
   Never crashes the app. */
const botapi = require('./botapi');
let mailer = null; try { mailer = require('./mailer'); } catch (e) { mailer = { configured: () => false, send: async () => ({}) }; }

module.exports = function (pool) {
  const wanotify = require('./wanotify')(pool);
  async function setting(k) { const r = await pool.query('SELECT value FROM wa_settings WHERE key=$1', [k]); return r.rows[0] ? r.rows[0].value : ''; }

  async function deliver(t) {
    try {
      const base = (await setting('site_base_url')) || '';
      const link = base ? (base.replace(/\/+$/, '') + '/account/trials') : '/account/trials';
      // UNIQUE_TRIAL_IDEMPOTENCY_v1: key off the globally-unique bot_ref (TRIAL-<id>-<hex>),
      // not the claim id — so a reused id (after a reset/clear) can never collide with an
      // old outbox row and get silently suppressed as "already sent".
      await wanotify.enqueue({
        customer_id: t.customer_id, destination_identity_id: t.whatsapp_identity_id, template_key: 'whatsapp.trial_ready',
        vars: { server_name: t.server_name || t.trial_type, duration_label: t.duration_label || (t.duration_hours ? (t.duration_hours + 'h') : 'trial'), secure_link: link, credentials: String(t.credentials || '') },
        idempotency_key: 'trial-' + (t.bot_ref || t.id)
      });
    } catch (e) {}
    try {
      if (mailer.configured && mailer.configured() && t.email) {
        const html = '<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;border:1px solid #eceef3;border-radius:14px">'
          + '<h2 style="margin:0 0 6px;color:#0f1424">Your ' + (t.server_name || 'trial') + ' is ready</h2>'
          + '<p style="color:#5a6276;font-size:14px">Valid for ' + (t.duration_label || ((t.duration_hours || '') + ' hours')) + '.</p>'
          + '<pre style="background:#f4f6fb;border-radius:10px;padding:14px;white-space:pre-wrap;word-break:break-word;font-size:13.5px">' + String(t.credentials || '') + '</pre></div>';
        await mailer.send(t.email, 'Your ' + (t.server_name || '') + ' trial is ready', html);
      }
    } catch (e) {}
  }

  async function tick() {
    if (!(botapi.configured && botapi.configured())) return;
    let rows = [];
    try {
      rows = (await pool.query(
        `SELECT tc.id, tc.customer_id, tc.whatsapp_identity_id, tc.trial_type, tc.server_name, tc.duration_hours, tc.bot_ref,
                c.email, c.ref_code, ts.duration_label
         FROM trial_claims tc JOIN customers c ON c.id=tc.customer_id
         LEFT JOIN trial_servers ts ON ts.sku=tc.trial_type
         WHERE tc.status='pending' AND tc.bot_ref IS NOT NULL AND tc.claimed_at > now() - interval '20 minutes'
         ORDER BY tc.id LIMIT 10`)).rows;
    } catch (e) { return; }
    for (const t of rows) {
      try {
        let st = null;
        try { st = await botapi.trialStatus(t.bot_ref); } catch (e) { st = null; }
        if (!st || typeof st.status === 'undefined') {
          // status unreachable — re-request (idempotent on request_id), try again next tick
          try { await botapi.generateTrial({ sku: t.trial_type, hours: t.duration_hours || 24, customer_ref: t.ref_code || '', request_id: t.bot_ref }); } catch (e) {}
          continue;
        }
        if (st.status === 'done' && st.credentials) {
          const exp = st.expires_at ? new Date(st.expires_at) : (t.duration_hours ? new Date(Date.now() + t.duration_hours * 3600 * 1000) : null);
          await pool.query("UPDATE trial_claims SET status='active', credentials=$1, expires_at=$2, bot_ref=$3 WHERE id=$4 AND status='pending'",
            [String(st.credentials), exp, String(st.trial_ref || t.bot_ref), t.id]);
          await deliver(Object.assign({}, t, { credentials: st.credentials }));
        } else if (st.status === 'failed') {
          await pool.query("UPDATE trial_claims SET status='failed', bot_ref=$1 WHERE id=$2 AND status='pending'", [String(st.error || 'failed').slice(0, 140), t.id]);
        }
        // 'pending' -> leave for next tick
      } catch (e) { /* skip this one */ }
    }
  }

  function startWorker() {
    const iv = parseInt(process.env.TRIAL_POLL_MS || '5000', 10);
    setInterval(() => { tick().catch(() => {}); }, iv);
    console.log('[trialpoll] worker started (every ' + iv + 'ms)');
  }

  return { startWorker, tick };
};
