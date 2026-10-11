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

  // wa_settings is a key/value table (same source the notifier uses).
  async function cfg() {
    try { const r = await pool.query('SELECT key,value FROM wa_settings'); const o = {}; r.rows.forEach(x => o[x.key] = x.value); return o; }
    catch (e) { return {}; }
  }
  function baseFrom(sendUrl) {
    try { const u = new URL(sendUrl); return u.protocol + '//' + u.host; } catch (e) { return process.env.WABOT_URL || 'http://127.0.0.1:8095'; }
  }
  function call(method, base, path, sec) {
    return new Promise((resolve) => {
      try {
        const u = new URL(base + path);
        const r = http.request(
          { hostname: u.hostname, port: u.port || 80, path: u.pathname, method, headers: { 'X-WA-Secret': sec } },
          (res) => { let b = ''; res.on('data', d => b += d); res.on('end', () => { try { resolve(JSON.parse(b)); } catch (e) { resolve(null); } }); });
        r.on('error', () => resolve(null));
        r.setTimeout(5000, () => { try { r.destroy(); } catch (e) {} resolve(null); });
        r.end();
      } catch (e) { resolve(null); }
    });
  }
  async function bot(method, path) {
    const c = await cfg();
    const base = c.wa_bot_send_url ? baseFrom(c.wa_bot_send_url) : (process.env.WABOT_URL || 'http://127.0.0.1:8095');
    return call(method, base, path, c.wa_bot_webhook_secret || '');
  }

  // Normalise to send-ready digits: strip non-digits; a local 0XXXXXXXXXX (PK) -> 92XXXXXXXXXX.
  function normNum(v) { let d = String(v || '').replace(/\D/g, ''); if (d.length === 11 && d[0] === '0') d = '92' + d.slice(1); return d; }

  router.get('/whatsapp', auth, async (req, res) => {
    const c = await cfg();
    res.render('admin/whatsapp', {
      active: 'whatsapp', title: 'WhatsApp Connection', flash: req.query.ok || null,
      nums: {
        verify: c.wa_verify_number || '', owner: c.wa_owner_numbers || '',
        support: c.wa_support_number || '', sales: c.wa_sales_number || ''
      }
    });
  });

  // Save any of the system's WhatsApp numbers; everything reads wa_settings live, so a
  // change here applies everywhere (verification link, support redirects, notifications,
  // store contact, admin reset code).
  router.post('/whatsapp/numbers', auth, body, async (req, res) => {
    const map = {
      wa_verify_number: req.body.verify, wa_owner_numbers: req.body.owner,
      wa_support_number: req.body.support, wa_sales_number: req.body.sales
    };
    try {
      for (const k in map) {
        if (map[k] === undefined) continue;
        await pool.query(
          'INSERT INTO wa_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=$2, updated_at=now()',
          [k, normNum(map[k])]);
      }
      res.redirect('/admin/whatsapp?ok=' + encodeURIComponent('Numbers saved — applied everywhere'));
    } catch (e) { res.redirect('/admin/whatsapp?ok=' + encodeURIComponent('Could not save numbers')); }
  });

  router.get('/whatsapp/status.json', auth, async (req, res) => {
    const s = await bot('GET', '/status');
    if (!s || s.ok === false) return res.json({ ok: true, reachable: false });
    let qrImg = null;
    if (s.qr && QRCode) { try { qrImg = await QRCode.toDataURL(s.qr, { margin: 1, width: 300 }); } catch (e) {} }
    res.json({
      ok: true, reachable: true, connected: !!s.connected,
      number: s.number || '', qrImg, hasQr: !!s.qr,
      connectedAt: s.connectedAt || null, uptimeMs: s.uptimeMs || 0
    });
  });

  router.post('/whatsapp/reconnect', auth, body, async (req, res) => {
    const r = await bot('POST', '/reconnect');
    res.json({ ok: !!(r && r.ok) });
  });
  router.post('/whatsapp/logout', auth, body, async (req, res) => {
    const r = await bot('POST', '/logout');
    res.json({ ok: !!(r && r.ok) });
  });

  return router;
};
