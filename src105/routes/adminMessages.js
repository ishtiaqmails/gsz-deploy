const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '256kb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  const NAMES = {
    'whatsapp.verification_success': 'WhatsApp verified',
    'whatsapp.order_received': 'Order received',
    'whatsapp.payment_confirmed': 'Payment confirmed',
    'whatsapp.order_completed': 'Order completed',
    'whatsapp.credentials': 'Credentials ready',
    'whatsapp.trial_ready': 'Trial ready',
    'whatsapp.password_reset': 'Password reset code',
    'whatsapp.subscription_expiry': 'Subscription expiry',
    'whatsapp.redirect_support': 'Verification-number auto-reply',
    'whatsapp.number_change': 'WhatsApp number changed',
    'whatsapp.security_alert': 'Security alert',
    'whatsapp.test': 'Test message'
  };
  const LANGS = [{ code: 'en', name: 'English', rtl: false }, { code: 'ur', name: 'Urdu', rtl: true }, { code: 'ar', name: 'Arabic', rtl: true }, { code: 'ro', name: 'Roman Urdu', rtl: false }];

  router.get('/messages', auth, async (req, res) => {
    const rows = (await pool.query('SELECT key, body, langs FROM wa_templates ORDER BY key')).rows;
    const enabled = (((await pool.query("SELECT value FROM wa_settings WHERE key='wa_langs'")).rows[0] || {}).value || 'en').split(',').map(x => x.trim()).filter(Boolean);
    res.render('admin/messages', { rows, names: NAMES, langs: LANGS, enabled, flash: req.query.ok || null });
  });

  router.post('/messages/langs', auth, body, async (req, res) => {
    const sel = [].concat(req.body.lang || []).filter(Boolean);
    const val = (sel.length ? sel : ['en']).join(',');
    await pool.query("INSERT INTO wa_settings(key,value) VALUES('wa_langs',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()", [val]);
    res.redirect('/admin/messages?ok=Languages+updated');
  });

  router.post('/messages/save', auth, body, async (req, res) => {
    const key = (req.body.key || '').trim(); if (!key) return res.redirect('/admin/messages');
    const langs = {};
    ['en', 'ur', 'ar', 'ro'].forEach(code => { const v = req.body['lang_' + code]; if (v != null && String(v).trim() !== '') langs[code] = String(v); });
    await pool.query("UPDATE wa_templates SET langs=$2, body=COALESCE($3, body), updated_at=now() WHERE key=$1", [key, JSON.stringify(langs), langs.en || null]);
    res.redirect('/admin/messages?ok=' + encodeURIComponent('Saved: ' + (NAMES[key] || key)));
  });

  return router;
};
