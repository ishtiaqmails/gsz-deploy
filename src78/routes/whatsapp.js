'use strict';
/* WhatsApp module Phase 2b — verification UX, status polling, and the inbound
   webhook the dedicated verification bot calls. Mounted at '/' in server.js.
   The identity engine (lib/waidentity) does resolution; this wires the flow,
   enforces collisions/rate limits, and writes the audit trail. Graceful:
   works (session + wa.me link) before the bot exists; completion arrives when
   the bot POSTs /internal/whatsapp/incoming with the shared secret. */
const express = require('express');
const crypto = require('crypto');
const storefront = require('../lib/storefront');
const waid = require('../lib/waidentity');

module.exports = function (pool) {
  const router = express.Router();
  const json = express.json({ limit: '64kb' });
  const body = express.urlencoded({ extended: true, limit: '64kb' });

  function requireLogin(req, res, next) {
    if (req.session && req.session.customer) return next();
    return res.redirect('/login?next=' + encodeURIComponent(req.originalUrl || '/account'));
  }
  const reqIp = req => String(req.headers['x-forwarded-for'] || req.ip || req.connection && req.connection.remoteAddress || '').split(',')[0].trim();
  const AL = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  function genCode() { let s = ''; const b = crypto.randomBytes(6); for (let i = 0; i < 6; i++) s += AL[b[i] % 32]; return 'GX-' + s; }
  function renderTpl(bodyStr, vars) { return String(bodyStr || '').replace(/\{\{(\w+)\}\}/g, (_, k) => (vars && vars[k] != null) ? String(vars[k]) : ''); }

  async function settings() { const r = await pool.query('SELECT key,value FROM wa_settings'); const o = {}; r.rows.forEach(x => o[x.key] = x.value); return o; }
  async function tpl(key) { const r = await pool.query('SELECT body FROM wa_templates WHERE key=$1', [key]); return r.rows[0] ? r.rows[0].body : ''; }
  async function audit(event, f) {
    try { await pool.query('INSERT INTO wa_audit_log(event,customer_id,identity_id,actor,ip,reason,new_value) VALUES($1,$2,$3,$4,$5,$6,$7)',
      [event, f.customer_id || null, f.identity_id || null, f.actor || 'system', f.ip || null, f.reason || null, f.new_value ? JSON.stringify(f.new_value) : null]); } catch (e) {}
  }
  async function waStatus(customerId) {
    const r = (await pool.query(
      `SELECT i.id, i.current_phone_e164, i.current_phone_verified, l.verified_at
       FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id
       WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1`, [customerId])).rows[0];
    return r ? { verified: true, identityId: r.id, phone: r.current_phone_e164 || '', phoneVerified: !!r.current_phone_verified, verifiedAt: r.verified_at } : { verified: false, phone: '' };
  }
  async function shell() {
    const cats = await storefront.loadCats(pool);
    const s = await storefront.loadSettings(pool);
    const products = await storefront.loadProducts(pool);
    const waNumber = s.wa_number || process.env.WA_NUMBER || '';
    return { cats, settings: s, waNumber, siteName: s.site_name || 'Galaxy Subz × Zayron', logoFile: s.logo_file || 'logo.png', shellJson: storefront.shellJson(cats, products, s, waNumber) };
  }

  // ---- WhatsApp settings / verify page ----
  router.get('/account/whatsapp', requireLogin, async (req, res) => {
    const s = await settings();
    const st = await waStatus(req.session.customer.id);
    let profileWa = '';
    try { const c = (await pool.query('SELECT wa_number FROM customers WHERE id=$1', [req.session.customer.id])).rows[0]; if (c && c.wa_number) profileWa = c.wa_number; } catch (e) {}
    res.render('account/whatsapp', Object.assign(await shell(), {
      title: 'WhatsApp', st, profileWa,
      cfg: { enabled: s.wa_verification_enabled === '1', hasNumber: !!s.wa_verify_number, botOnline: s.wa_bot_status === 'CONNECTED' }
    }));
  });

  // ---- start verification ----
  router.post('/api/whatsapp/verification/start', json, body, requireLogin, async (req, res) => {
    const cust = req.session.customer; const s = await settings();
    if (s.wa_verification_enabled !== '1') return res.status(503).json({ error: 'disabled', message: 'WhatsApp verification is currently turned off.' });
    if (!s.wa_verify_number) return res.status(503).json({ error: 'no_number', message: 'WhatsApp verification is temporarily unavailable. Please try again shortly.' });
    const cur = await waStatus(cust.id);
    if (cur.verified) return res.json({ already: true, message: 'Your WhatsApp is already verified.' });
    const rl = parseInt(s.wa_verify_rate_limit || '5', 10);
    const mins = parseInt(s.wa_verify_token_expiry_minutes || '15', 10);
    const recent = (await pool.query("SELECT count(*)::int n FROM whatsapp_verification_sessions WHERE customer_id=$1 AND created_at > now() - interval '1 hour'", [cust.id])).rows[0].n;
    if (recent >= rl * 3) return res.status(429).json({ error: 'rate', message: 'Too many verification attempts. Please try again later.' });
    await pool.query("UPDATE whatsapp_verification_sessions SET status='EXPIRED', updated_at=now() WHERE customer_id=$1 AND status='PENDING'", [cust.id]);
    let code, id;
    for (let t = 0; t < 6; t++) {
      code = genCode();
      try {
        const hash = crypto.createHash('sha256').update(code).digest('hex');
        const r = await pool.query(
          `INSERT INTO whatsapp_verification_sessions(customer_id,token_hash,display_code,purpose,status,expires_at,requested_ip,requested_user_agent)
           VALUES($1,$2,$3,'ACCOUNT_VERIFY','PENDING', now() + ($4||' minutes')::interval, $5,$6) RETURNING id`,
          [cust.id, hash, code, String(mins), reqIp(req), String(req.headers['user-agent'] || '').slice(0, 250)]);
        id = r.rows[0].id; break;
      } catch (e) { if (t === 5) return res.status(500).json({ error: 'server', message: 'Could not start verification. Please try again.' }); }
    }
    await audit('WHATSAPP_VERIFICATION_STARTED', { customer_id: cust.id, ip: reqIp(req) });
    const text = 'VERIFY ' + code;
    const waLink = 'https://wa.me/' + String(s.wa_verify_number).replace(/[^0-9]/g, '') + '?text=' + encodeURIComponent(text);
    res.json({ id, code, text, waLink, expiresInMin: mins });
  });

  // ---- poll status ----
  router.get('/api/whatsapp/verification/:id/status', requireLogin, async (req, res) => {
    const r = (await pool.query('SELECT status FROM whatsapp_verification_sessions WHERE id=$1 AND customer_id=$2',
      [parseInt(req.params.id, 10) || 0, req.session.customer.id])).rows[0];
    if (!r) return res.status(404).json({ status: 'NOT_FOUND' });
    res.json({ status: r.status });
  });

  // ---- inbound webhook (called by the dedicated verification bot) ----
  router.post('/internal/whatsapp/incoming', json, async (req, res) => {
    const s = await settings();
    const secret = req.headers['x-wa-secret'] || '';
    if (!s.wa_bot_webhook_secret || secret !== s.wa_bot_webhook_secret) return res.status(401).json({ ok: false, error: 'unauthorized' });
    const b = req.body || {};
    const text = String(b.text || b.message || '').trim();
    // Build identity parts WITHOUT letting a LID masquerade as a phone/PN.
    const parts = { lid: b.lid || b.senderLid || null, pnJid: (b.pnJid && /@(s\.whatsapp\.net|c\.us)$/i.test(b.pnJid)) ? b.pnJid : null, phone: b.phone || null };
    const rawJid = String(b.jid || b.from || '');
    if (rawJid) {
      if (/@lid$/i.test(rawJid)) { if (!parts.lid) parts.lid = rawJid; }
      else if (/@(s\.whatsapp\.net|c\.us)$/i.test(rawJid)) { if (!parts.pnJid) parts.pnJid = rawJid; }
    }
    // bot heartbeat
    try {
      await pool.query("INSERT INTO wa_settings(key,value) VALUES('wa_bot_status','CONNECTED') ON CONFLICT(key) DO UPDATE SET value='CONNECTED',updated_at=now()");
      await pool.query("INSERT INTO wa_settings(key,value) VALUES('wa_last_message_received_at',now()::text) ON CONFLICT(key) DO UPDATE SET value=now()::text,updated_at=now()");
    } catch (e) {}

    const m = text.match(/VERIFY\s+([A-Z0-9-]{4,})/i);
    if (!m) {
      const reply = renderTpl(await tpl('whatsapp.redirect_support'), { sales_number: s.wa_sales_number, support_number: s.wa_support_number, customer_reference: '' });
      return res.json({ ok: true, action: 'REDIRECT', reply });
    }
    const code = m[1].toUpperCase();
    const c = await pool.connect();
    try {
      await c.query('BEGIN');
      const sess = (await c.query("SELECT * FROM whatsapp_verification_sessions WHERE display_code=$1 AND status='PENDING' FOR UPDATE", [code])).rows[0];
      if (!sess) { await c.query('ROLLBACK'); return res.json({ ok: true, action: 'NO_SESSION', reply: 'This verification code is invalid or has already been used. Please start again from the website.' }); }
      if (new Date(sess.expires_at) < new Date()) {
        await c.query("UPDATE whatsapp_verification_sessions SET status='EXPIRED', updated_at=now() WHERE id=$1", [sess.id]);
        await c.query('COMMIT');
        return res.json({ ok: true, action: 'EXPIRED', reply: 'This verification code has expired. Please start again from the website.' });
      }
      const { identity } = await waid.resolveOrCreateIdentity(c, parts, { phoneVerified: !!parts.phone });
      const other = (await c.query("SELECT customer_id FROM customer_whatsapp_links WHERE whatsapp_identity_id=$1 AND status='ACTIVE' LIMIT 1", [identity.id])).rows[0];
      if (other && other.customer_id !== sess.customer_id) {
        await c.query("UPDATE whatsapp_verification_sessions SET status='FAILED', whatsapp_identity_id=$2, updated_at=now() WHERE id=$1", [sess.id, identity.id]);
        await c.query('COMMIT');
        await audit('WHATSAPP_VERIFICATION_FAILED', { customer_id: sess.customer_id, identity_id: identity.id, reason: 'IDENTITY_ALREADY_LINKED' });
        return res.json({ ok: true, action: 'IDENTITY_ALREADY_LINKED', reply: 'This WhatsApp is already linked to another account. Please contact support if this is you.' });
      }
      const existing = (await c.query("SELECT whatsapp_identity_id FROM customer_whatsapp_links WHERE customer_id=$1 AND status='ACTIVE' AND is_primary=true LIMIT 1", [sess.customer_id])).rows[0];
      if (existing && existing.whatsapp_identity_id !== identity.id) {
        await c.query("UPDATE whatsapp_verification_sessions SET status='FAILED', whatsapp_identity_id=$2, updated_at=now() WHERE id=$1", [sess.id, identity.id]);
        await c.query('COMMIT');
        return res.json({ ok: true, action: 'ALREADY_HAS_WA', reply: 'Your account already has a verified WhatsApp. Use "Change WhatsApp" on the website to switch numbers.' });
      }
      if (!existing) {
        await c.query("INSERT INTO customer_whatsapp_links(customer_id,whatsapp_identity_id,is_primary,status,verified_at,link_reason) VALUES($1,$2,true,'ACTIVE',now(),'INITIAL_VERIFICATION')", [sess.customer_id, identity.id]);
      }
      await c.query("UPDATE whatsapp_verification_sessions SET status='VERIFIED', whatsapp_identity_id=$2, completed_at=now(), updated_at=now() WHERE id=$1", [sess.id, identity.id]);
      await c.query('COMMIT');
      await audit('WHATSAPP_VERIFICATION_COMPLETED', { customer_id: sess.customer_id, identity_id: identity.id });
      try {
        const cust = (await pool.query('SELECT ref_code FROM customers WHERE id=$1', [sess.customer_id])).rows[0] || {};
        await pool.query("INSERT INTO wa_notifications(customer_id,destination_identity_id,template_key,vars,idempotency_key) VALUES($1,$2,'whatsapp.verification_success',$3,$4) ON CONFLICT(idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING",
          [sess.customer_id, identity.id, JSON.stringify({ site_name: 'Galaxy Subz × Zayron', customer_reference: cust.ref_code || '' }), 'verif-ok-' + sess.id]);
      } catch (e) {}
      const reply = renderTpl(await tpl('whatsapp.verification_success'), { site_name: 'Galaxy Subz × Zayron', customer_reference: '' });
      return res.json({ ok: true, action: 'VERIFIED', reply });
    } catch (e) {
      try { await c.query('ROLLBACK'); } catch (_) {}
      console.log('[wa incoming] ' + e.message);
      return res.status(500).json({ ok: false, error: 'server' });
    } finally { c.release(); }
  });

  return router;
};
