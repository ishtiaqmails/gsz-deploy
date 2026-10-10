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

  // --- list / edit form ---
  router.get('/payments', auth, async (req, res) => {
    try {
      const rows = (await pool.query(
        'SELECT id, key, name, currency, scope, details, instructions, active, sort, logo FROM payment_methods ORDER BY sort, id'
      )).rows;
      res.render('admin/payments', { rows, flash: req.query.ok || null, active: 'payments', title: 'Payments' });
    } catch (e) { res.status(500).send('Payments error: ' + e.message); }
  });

  // --- save all methods (bulk) ---
  router.post('/payments', auth, express.urlencoded({ extended: true, limit: '1mb' }), async (req, res) => {
    const m = (req.body && req.body.m) || {};
    const SCOPES = ['all', 'pk', 'global'];
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const id of Object.keys(m)) {
        const pid = parseInt(id, 10);
        if (!Number.isFinite(pid)) continue;
        const r = m[id] || {};
        const name = String(r.name || '').trim();
        if (!name) continue;
        const currency = (String(r.currency || 'USD').trim().toUpperCase().slice(0, 8)) || 'USD';
        const scope = SCOPES.includes(String(r.scope || '')) ? r.scope : 'all';
        const details = String(r.details || '').trim();
        const instructions = String(r.instructions || '').trim();
        const activeOn = (r.active === 'on' || r.active === 'true' || r.active === true);
        const sortNum = parseInt(r.sort, 10);
        const sortv = Number.isFinite(sortNum) ? sortNum : 0;
        await client.query(
          'UPDATE payment_methods SET name=$1, currency=$2, scope=$3, details=$4, instructions=$5, active=$6, sort=$7 WHERE id=$8',
          [name, currency, scope, details, instructions, activeOn, sortv, pid]
        );
      }
      await client.query('COMMIT');
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Payment details saved'));
    } catch (e) {
      try { await client.query('ROLLBACK'); } catch (x) {}
      res.status(500).send('Payments save error: ' + e.message);
    } finally { client.release(); }
  });

  // --- upload a logo for one method ---
  router.post('/payments/:id/logo', auth, upload.single('logo'), async (req, res) => {
    const pid = parseInt(req.params.id, 10);
    if (!Number.isFinite(pid)) return res.redirect('/admin/payments?ok=' + encodeURIComponent('Invalid method'));
    if (!req.file) return res.redirect('/admin/payments?ok=' + encodeURIComponent('Please choose an image file'));
    try {
      const ext = path.extname(req.file.filename).toLowerCase() || '.png';
      const dest = 'pm-' + pid + '-' + Date.now() + ext;
      fs.renameSync(path.join(IMG_DIR, req.file.filename), path.join(IMG_DIR, dest));
      const prev = (await pool.query('SELECT logo FROM payment_methods WHERE id=$1', [pid])).rows[0];
      if (prev && prev.logo && prev.logo !== dest) { try { fs.unlinkSync(path.join(IMG_DIR, prev.logo)); } catch (e) {} }
      await pool.query('UPDATE payment_methods SET logo=$1 WHERE id=$2', [dest, pid]);
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo updated'));
    } catch (e) {
      try { fs.unlinkSync(path.join(IMG_DIR, req.file.filename)); } catch (x) {}
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo upload failed'));
    }
  });

  // --- remove a logo ---
  router.post('/payments/:id/logo/remove', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const pid = parseInt(req.params.id, 10);
    if (!Number.isFinite(pid)) return res.redirect('/admin/payments');
    try {
      const prev = (await pool.query('SELECT logo FROM payment_methods WHERE id=$1', [pid])).rows[0];
      if (prev && prev.logo) { try { fs.unlinkSync(path.join(IMG_DIR, prev.logo)); } catch (e) {} }
      await pool.query('UPDATE payment_methods SET logo=NULL WHERE id=$1', [pid]);
    } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo removed'));
  });

  return router;
};
