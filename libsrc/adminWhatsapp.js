'use strict';
/* Admin — WhatsApp Connection. Live control panel for the GSZ verification bot
   (gszwabot). Talks to its secret-gated control API over localhost:
     GET /status  ->  connection + current QR
     POST /reconnect, POST /logout
   The shared secret comes from wa_settings.wa_bot_webhook_secret (same value the
   bot runs with). QR strings are rendered to a data-URL here so the page just shows
   an <img>. Admin-only. Never touches the reseller bot. */
const express = require('express');
const http = require('http');
const { URL } = require('url');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '256kb' });
  let QRCode = null; try { QRCode = require('qrcode'); } catch (e) { /* optional; status still works without QR image */ }
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  const WABOT = process.env.WABOT_URL || 'http://127.0.0.1:8095';

  async function secret() {
    try { const r = (await pool.query('SELECT wa_bot_webhook_secret FROM wa_settings LIMIT 1')).rows[0]; return (r && r.wa_bot_webhook_secret) || ''; }
    catch (e) { return ''; }
  }
  function call(method, path, sec) {
    return new Promise((resolve) => {
      try {
        const u = new URL(WABOT + path);
        const r = http.request(
          { hostname: u.hostname, port: u.port || 80, path: u.pathname, method, headers: { 'X-WA-Secret': sec } },
          (res) => { let b = ''; res.on('data', d => b += d); res.on('end', () => { try { resolve(JSON.parse(b)); } catch (e) { resolve(null); } }); });
        r.on('error', () => resolve(null));
        r.setTimeout(5000, () => { try { r.destroy(); } catch (e) {} resolve(null); });
        r.end();
      } catch (e) { resolve(null); }
    });
  }

  router.get('/whatsapp', auth, (req, res) => {
    res.render('admin/whatsapp', { active: 'whatsapp', title: 'WhatsApp Connection', flash: req.query.ok || null });
  });

  router.get('/whatsapp/status.json', auth, async (req, res) => {
    const s = await call('GET', '/status', await secret());
    if (!s) return res.json({ ok: true, reachable: false });
    let qrImg = null;
    if (s.qr && QRCode) { try { qrImg = await QRCode.toDataURL(s.qr, { margin: 1, width: 300 }); } catch (e) {} }
    res.json({
      ok: true, reachable: true, connected: !!s.connected,
      number: s.number || '', qrImg, hasQr: !!s.qr,
      connectedAt: s.connectedAt || null, uptimeMs: s.uptimeMs || 0
    });
  });

  router.post('/whatsapp/reconnect', auth, body, async (req, res) => {
    const r = await call('POST', '/reconnect', await secret());
    res.json({ ok: !!(r && r.ok) });
  });
  router.post('/whatsapp/logout', auth, body, async (req, res) => {
    const r = await call('POST', '/logout', await secret());
    res.json({ ok: !!(r && r.ok) });
  });

  return router;
};
