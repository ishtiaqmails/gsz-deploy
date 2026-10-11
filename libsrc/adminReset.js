'use strict';
/* Admin password reset via a code sent to the OWNER WhatsApp number (gszwabot).
   - GET  /admin/forgot  -> "Send Reset Code" card (owner number read live from wa_settings)
   - POST /admin/forgot  -> make a 6-digit code, store it, send it to the owner via the bot
   - GET  /admin/reset   -> enter code + new password
   - POST /admin/reset   -> verify code, save the new password HASH in admin_auth
   The login (routes/admin.js) checks admin_auth first, falling back to .env ADMIN_PASS,
   so a reset works at runtime with no file edits. Codes expire in 15 min, single-use,
   max 6 attempts, max 3 sends / 15 min. Nothing hardcoded. */
const express = require('express');
const crypto = require('crypto');
const http = require('http');
const { URL } = require('url');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: false });

  function hashPw(pw) { const salt = crypto.randomBytes(16); const h = crypto.scryptSync(String(pw), salt, 64); return salt.toString('hex') + ':' + h.toString('hex'); }
  function genCode() { return String(crypto.randomInt(100000, 1000000)); }
  function normNum(v) { let d = String(v || '').replace(/\D/g, ''); if (d.length === 11 && d[0] === '0') d = '92' + d.slice(1); return d; }
  function mask(n) { n = String(n || ''); return n.length < 4 ? '••••' : ('•••••• ' + n.slice(-3)); }
  function baseFrom(u) { try { const x = new URL(u); return x.protocol + '//' + x.host; } catch (e) { return process.env.WABOT_URL || 'http://127.0.0.1:8095'; } }

  async function cfg() { try { const r = await pool.query('SELECT key,value FROM wa_settings'); const o = {}; r.rows.forEach(x => o[x.key] = x.value); return o; } catch (e) { return {}; } }

  function botSend(base, sec, to, text) {
    return new Promise((resolve) => {
      try {
        const u = new URL(base + '/send');
        const data = Buffer.from(JSON.stringify({ to, text }));
        const r = http.request({ hostname: u.hostname, port: u.port || 80, path: u.pathname, method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Content-Length': data.length, 'X-WA-Secret': sec } },
          (res) => { let b = ''; res.on('data', d => b += d); res.on('end', () => { try { resolve(JSON.parse(b)); } catch (e) { resolve(null); } }); });
        r.on('error', () => resolve(null));
        r.setTimeout(8000, () => { try { r.destroy(); } catch (e) {} resolve(null); });
        r.write(data); r.end();
      } catch (e) { resolve(null); }
    });
  }

  router.get('/forgot', async (req, res) => {
    const c = await cfg(); const owner = normNum(c.wa_owner_numbers || '');
    res.render('admin/forgot', { masked: owner ? mask(owner) : '', error: null });
  });

  router.post('/forgot', body, async (req, res) => {
    const c = await cfg(); const owner = normNum(c.wa_owner_numbers || '');
    if (!owner) return res.render('admin/forgot', { masked: '', error: 'No owner WhatsApp number is set. Add one in Admin → WhatsApp → Numbers.' });
    try {
      const recent = (await pool.query("SELECT count(*)::int n FROM admin_reset WHERE created_at > now() - interval '15 minutes'")).rows[0].n;
      if (recent >= 3) return res.render('admin/forgot', { masked: mask(owner), error: 'Too many requests. Please wait a few minutes and try again.' });
    } catch (e) {}
    const code = genCode();
    try { await pool.query("INSERT INTO admin_reset(code,expires_at) VALUES($1, now() + interval '15 minutes')", [code]); }
    catch (e) { return res.render('admin/forgot', { masked: mask(owner), error: 'Could not start a reset. Please try again.' }); }
    const base = c.wa_bot_send_url ? baseFrom(c.wa_bot_send_url) : (process.env.WABOT_URL || 'http://127.0.0.1:8095');
    const text = 'Galaxy Subz × Zayron — Admin password reset code: ' + code + '\nValid for 15 minutes. If you did not request this, ignore this message.';
    const r = await botSend(base, c.wa_bot_webhook_secret || '', owner, text);
    if (!r || !r.ok) return res.render('admin/forgot', { masked: mask(owner), error: 'Could not send the code (is the verification bot connected?). Try again shortly.' });
    res.redirect('/admin/reset?sent=1');
  });

  router.get('/reset', (req, res) => {
    res.render('admin/reset', { error: null, info: req.query.sent ? 'A reset code was sent to the owner WhatsApp number.' : null, done: false });
  });

  router.post('/reset', body, async (req, res) => {
    const code = String(req.body.code || '').replace(/\D/g, '').trim();
    const pw = String(req.body.password || ''); const pw2 = String(req.body.password2 || '');
    const re = (err) => res.status(400).render('admin/reset', { error: err, info: null, done: false });
    if (!code) return re('Enter the code sent to WhatsApp.');
    if (pw.length < 8) return re('New password must be at least 8 characters.');
    if (pw !== pw2) return re('The two passwords do not match.');

    let row;
    try { row = (await pool.query("SELECT id FROM admin_reset WHERE code=$1 AND used=false AND expires_at>now() AND tries<6 ORDER BY id DESC LIMIT 1", [code])).rows[0]; } catch (e) {}
    if (!row) {
      // burn an attempt on the newest open session to throttle guessing
      try { await pool.query("UPDATE admin_reset SET tries=tries+1 WHERE id=(SELECT id FROM admin_reset WHERE used=false AND expires_at>now() ORDER BY id DESC LIMIT 1)"); } catch (e) {}
      return re('That code is wrong or has expired. Request a new one if needed.');
    }
    try {
      await pool.query("INSERT INTO admin_auth(id,pass_hash,updated_at) VALUES(1,$1,now()) ON CONFLICT(id) DO UPDATE SET pass_hash=$1, updated_at=now()", [hashPw(pw)]);
      await pool.query("UPDATE admin_reset SET used=true WHERE used=false"); // consume all open sessions
    } catch (e) { return re('Could not save the new password. Please try again.'); }
    res.render('admin/reset', { error: null, info: null, done: true });
  });

  return router;
};
