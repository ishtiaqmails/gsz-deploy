const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');

module.exports = function (pool) {
  const router = express.Router();
  const IMG_DIR = path.join(__dirname, '..', 'public', 'img');
  fs.mkdirSync(IMG_DIR, { recursive: true });

  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, IMG_DIR),
    filename: (req, file, cb) => cb(null, '__pmlogo_' + Date.now() + path.extname(file.originalname || '').toLowerCase())
  });
  const okImg = /\.(jpg|jpeg|png|webp|gif|svg)$/i;
  const upload = multer({
    storage,
    limits: { fileSize: 6 * 1024 * 1024 },
    fileFilter: (req, file, cb) => cb(null, okImg.test(file.originalname || ''))
  });

  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }
  function botMod() { try { return require('../lib/botapi'); } catch (e) { return null; } }

  async function logoMap() {
    const map = {};
    try { (await pool.query('SELECT key, logo, sort FROM payment_logos')).rows.forEach(r => { map[r.key] = { logo: r.logo, sort: (r.sort == null ? 100 : r.sort) }; }); } catch (e) {}
    return map;
  }

  // --- list live payment methods (from the reseller bot) + their GSZ logos ---
  router.get('/payments', auth, async (req, res) => {
    let methods = [], source = 'bot';
    try {
      const bot = botMod();
      if (bot && bot.configured && bot.configured()) {
        const accts = await bot.getPayAccounts();
        methods = (accts || []).map(a => ({
          key: String(a.key || ''),
          name: a.label || a.method || a.name || a.key,
          currency: String(a.currency || 'PKR').toUpperCase(),
          details: a.details || ((a.title ? ('Title: ' + a.title) : '') + (a.account ? ('\nAccount: ' + a.account) : '')).trim()
        })).filter(m => m.key);
      }
    } catch (e) {}
    if (!methods.length) {
      source = 'local';
      try {
        methods = (await pool.query("SELECT key, name, currency, details FROM payment_methods WHERE active ORDER BY sort, id")).rows
          .map(m => ({ key: m.key, name: m.name, currency: (m.currency || 'PKR'), details: m.details || '' }));
      } catch (e) {}
    }
    const lm = await logoMap();
    methods.forEach(m => { const info = lm[m.key] || {}; m.logo = info.logo || null; m.sort = (info.sort == null ? 100 : info.sort); });
    methods.sort((a, b) => a.sort - b.sort);
    res.render('admin/payments', { methods, source, flash: req.query.ok || null, active: 'payments', title: 'Payments' });
  });

  // --- set display order for one method (by bot key) ---
  router.post('/payments/order', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    const sort = parseInt(req.body && req.body.sort, 10);
    if (!key || !Number.isFinite(sort)) return res.redirect('/admin/payments');
    try {
      await pool.query('INSERT INTO payment_logos(key, sort) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET sort=EXCLUDED.sort, updated_at=now()', [key, sort]);
    } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Order updated'));
  });

  // --- upload a logo for one method (by bot key) ---
  router.post('/payments/logo', auth, upload.single('logo'), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    if (!key) return res.redirect('/admin/payments?ok=' + encodeURIComponent('Missing method'));
    if (!req.file) return res.redirect('/admin/payments?ok=' + encodeURIComponent('Please choose an image file'));
    try {
      const ext = path.extname(req.file.filename).toLowerCase() || '.png';
      const safe = key.replace(/[^a-z0-9_-]/gi, '').slice(0, 40) || 'pm';
      const dest = 'pm-' + safe + '-' + Date.now() + ext;
      fs.renameSync(path.join(IMG_DIR, req.file.filename), path.join(IMG_DIR, dest));
      const prev = (await pool.query('SELECT logo FROM payment_logos WHERE key=$1', [key])).rows[0];
      if (prev && prev.logo && prev.logo !== dest) { try { fs.unlinkSync(path.join(IMG_DIR, prev.logo)); } catch (e) {} }
      await pool.query(
        'INSERT INTO payment_logos(key, logo) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET logo=EXCLUDED.logo, updated_at=now()',
        [key, dest]
      );
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo updated'));
    } catch (e) {
      try { fs.unlinkSync(path.join(IMG_DIR, req.file.filename)); } catch (x) {}
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo upload failed'));
    }
  });

  // --- remove a logo ---
  router.post('/payments/logo/remove', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    if (!key) return res.redirect('/admin/payments');
    try {
      const prev = (await pool.query('SELECT logo FROM payment_logos WHERE key=$1', [key])).rows[0];
      if (prev && prev.logo) { try { fs.unlinkSync(path.join(IMG_DIR, prev.logo)); } catch (e) {} }
      await pool.query('DELETE FROM payment_logos WHERE key=$1', [key]);
    } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo removed'));
  });

  return router;
};
