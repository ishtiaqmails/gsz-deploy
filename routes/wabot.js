'use strict';
/* routes/wabot.js — WhatsApp Control Center (admin).
 *   GET  /admin/wabot            the control panel (connection + numbers + toggles)
 *   GET  /admin/wabot/qr.json    live bot status + QR (reads the bot's /status),
 *                                auto-syncs wa_verify_number to the connected number
 *   POST /admin/wabot/numbers    save store/owner/sales/support numbers (propagate everywhere)
 *   POST /admin/wabot/toggles    verification system + per-action gates + order notifications
 *   POST /admin/wabot/reconnect  ask the bot to reconnect
 *   POST /admin/wabot/relogin    log the bot out -> fresh QR to re-scan
 * Numbers are read live from settings/wa_settings across the site, so a change here
 * takes effect everywhere immediately. Same /admin session guard as the rest of admin.
 */
const express = require('express');
const http = require('http');
const https = require('https');
const { URL } = require('url');
let qrlib = null; try { qrlib = require('qrcode'); } catch (e) { /* optional */ }

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '64kb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  async function botOrigin() {
    let origin = 'http://127.0.0.1:8095';
    try { const r = (await pool.query("SELECT value FROM wa_settings WHERE key='wa_bot_send_url'")).rows[0]; if (r && r.value) { const u = new URL(r.value); origin = u.protocol + '//' + u.host; } } catch (e) {}
    return origin;
  }
  async function botSecret() {
    try { const r = (await pool.query("SELECT value FROM wa_settings WHERE key='wa_bot_webhook_secret'")).rows[0]; return (r && r.value) || process.env.WA_WEBHOOK_SECRET || ''; } catch (e) { return process.env.WA_WEBHOOK_SECRET || ''; }
  }
  function reqJson(method, origin, pth, secret, payload) {
    return new Promise((resolve) => {
      try {
        const u = new URL(origin + pth);
        const data = payload ? Buffer.from(JSON.stringify(payload)) : null;
        const mod = u.protocol === 'https:' ? https : http;
        const headers = { 'X-WA-Secret': secret };
        if (data) { headers['Content-Type'] = 'application/json'; headers['Content-Length'] = data.length; }
        const r = mod.request({ hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80), path: u.pathname, method, headers, timeout: 6000 },
          (res) => { let b = ''; res.on('data', d => b += d); res.on('end', () => { try { resolve(JSON.parse(b)); } catch (e) { resolve(null); } }); });
        r.on('error', () => resolve(null));
        r.on('timeout', () => { try { r.destroy(); } catch (e) {} resolve(null); });
        if (data) r.write(data); r.end();
      } catch (e) { resolve(null); }
    });
  }
  const getJson = (o, p, s) => reqJson('GET', o, p, s);
  const postJson = (o, p, s, b) => reqJson('POST', o, p, s, b || {});

  async function waSettings() { const o = {}; try { (await pool.query('SELECT key,value FROM wa_settings')).rows.forEach(r => o[r.key] = r.value); } catch (e) {} return o; }
  async function siteSettings() { const o = {}; try { (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => o[r.key] = r.value); } catch (e) {} return o; }
  async function setWa(key, val) { await pool.query("INSERT INTO wa_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()", [key, String(val)]); }
  async function setSite(key, val) { await pool.query("INSERT INTO settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value", [key, String(val)]); }
  const digits = v => String(v == null ? '' : v).replace(/[^0-9]/g, '');
  const digitsList = v => String(v == null ? '' : v).split(/[,\s]+/).map(x => x.replace(/[^0-9]/g, '')).filter(x => x.length >= 7).join(', ');

  // ---- control center ----
  router.get('/wabot', auth, async (req, res) => {
    const wa = await waSettings(); const site = await siteSettings();
    res.render('admin/wabot', {
      title: 'WhatsApp Control Center', active: 'wabot',
      flash: req.query.ok || null, err: req.query.err || null,
      numbers: {
        store: site.wa_number || '',
        verify: wa.wa_verify_number || '',
        owner: wa.wa_owner_numbers || '',
        sales: wa.wa_sales_number || '',
        support: wa.wa_support_number || ''
      },
      toggles: {
        verificationEnabled: wa.wa_verification_enabled === '1',
        requireCheckout: (wa.require_wa_verify || 'on') !== 'off',
        requireTrial: (wa.require_wa_trial || 'on') !== 'off',
        orderNotifications: wa.wa_order_notifications_enabled === '1'
      }
    });
  });

  // ---- live status + QR (bot /status); auto-sync verify number to the connected bot ----
  router.get('/wabot/qr.json', auth, async (req, res) => {
    const origin = await botOrigin(); const secret = await botSecret();
    const d = await getJson(origin, '/status', secret);
    if (!d) return res.json({ ok: false, reachable: false, status: 'offline', connected: false });
    let qrDataUrl = null;
    if (d.qr && qrlib) { try { qrDataUrl = await qrlib.toDataURL(d.qr, { margin: 1, width: 300 }); } catch (e) {} }
    try { if (d.connected && d.number) { await setWa('wa_verify_number', digits(d.number)); } } catch (e) {}
    res.json({ ok: true, reachable: true, status: (d.connected ? 'connected' : (d.qr ? 'qr' : 'connecting')), connected: !!d.connected, number: d.number || null, user: d.user || null, qrDataUrl });
  });

  // ---- live activity + stats (watch the bot moment-to-moment) ----
  router.get('/wabot/activity.json', auth, async (req, res) => {
    try {
      const q = async (sql, p) => { try { return (await pool.query(sql, p || [])).rows; } catch (e) { return []; } };
      const todayKhi = "(created_at AT TIME ZONE 'Asia/Karachi')::date = (now() AT TIME ZONE 'Asia/Karachi')::date";
      const events = await q("SELECT event, reason, created_at FROM wa_audit_log ORDER BY id DESC LIMIT 30");
      const verifiedCustomers = (await q("SELECT count(*)::int n FROM customer_whatsapp_links WHERE status='ACTIVE' AND is_primary=true"))[0] || { n: 0 };
      const verifiedToday = (await q("SELECT count(*)::int n FROM wa_audit_log WHERE event='WHATSAPP_VERIFICATION_COMPLETED' AND " + todayKhi))[0] || { n: 0 };
      const startedToday = (await q("SELECT count(*)::int n FROM wa_audit_log WHERE event='WHATSAPP_VERIFICATION_STARTED' AND " + todayKhi))[0] || { n: 0 };
      const messagesToday = (await q("SELECT count(*)::int n FROM wa_audit_log WHERE event='VERIFY_NUMBER_MSG' AND " + todayKhi))[0] || { n: 0 };
      const lastMsg = (await q("SELECT value FROM wa_settings WHERE key='wa_last_message_received_at'"))[0];
      res.json({
        ok: true,
        stats: { verifiedCustomers: verifiedCustomers.n, verifiedToday: verifiedToday.n, startedToday: startedToday.n, messagesToday: messagesToday.n },
        lastMessageAt: lastMsg ? lastMsg.value : null,
        events: events.map(e => ({ event: e.event, reason: e.reason || '', at: e.created_at }))
      });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  // ---- save numbers (propagate everywhere) ----
  router.post('/wabot/numbers', auth, body, async (req, res) => {
    try {
      const b = req.body || {};
      if (b.store != null) await setSite('wa_number', digits(b.store));
      if (b.owner != null) await setWa('wa_owner_numbers', digitsList(b.owner));
      if (b.sales != null) await setWa('wa_sales_number', digits(b.sales));
      if (b.support != null) await setWa('wa_support_number', digits(b.support));
      res.redirect('/admin/wabot?ok=' + encodeURIComponent('Numbers saved — live everywhere now.'));
    } catch (e) { res.redirect('/admin/wabot?err=' + encodeURIComponent('Save failed: ' + e.message)); }
  });

  // ---- save verification toggles ----
  router.post('/wabot/toggles', auth, body, async (req, res) => {
    try {
      const on = v => (v === 'on' || v === '1' || v === 'true');
      await setWa('wa_verification_enabled', on(req.body.verificationEnabled) ? '1' : '0');
      await setWa('require_wa_verify', on(req.body.requireCheckout) ? 'on' : 'off');
      await setWa('require_wa_trial', on(req.body.requireTrial) ? 'on' : 'off');
      await setWa('wa_order_notifications_enabled', on(req.body.orderNotifications) ? '1' : '0');
      res.redirect('/admin/wabot?ok=' + encodeURIComponent('Verification settings saved.'));
    } catch (e) { res.redirect('/admin/wabot?err=' + encodeURIComponent('Save failed: ' + e.message)); }
  });

  // ---- bot actions ----
  router.post('/wabot/reconnect', auth, body, async (req, res) => {
    const origin = await botOrigin(); const secret = await botSecret();
    await postJson(origin, '/reconnect', secret, {});
    res.redirect('/admin/wabot?ok=' + encodeURIComponent('Reconnect requested.'));
  });
  router.post('/wabot/relogin', auth, body, async (req, res) => {
    const origin = await botOrigin(); const secret = await botSecret();
    await postJson(origin, '/logout', secret, {});
    res.redirect('/admin/wabot?ok=' + encodeURIComponent('Bot logged out — a new QR appears below in a few seconds. Scan it from the bot phone.'));
  });

  return router;
};
