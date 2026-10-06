const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  // List IPTV servers (from bot mapping) with their trial config.
  router.get('/trials', auth, async (req, res) => {
    let rows = [];
    try {
      rows = (await pool.query(
        `SELECT bp.sku, bp.name, ts.enabled, ts.duration_label, ts.duration_hours, ts.max_per_customer
         FROM bot_products bp LEFT JOIN trial_servers ts ON ts.sku = bp.sku
         WHERE lower(coalesce(bp.delivery_type,'')) = 'iptv'
         ORDER BY bp.name`)).rows;
    } catch (e) { rows = []; }
    res.render('admin/trials', { rows, flash: req.query.ok || null });
  });

  // Save one server's trial config.
  router.post('/trials/save', auth, body, async (req, res) => {
    const b = req.body; const sku = (b.sku || '').trim();
    if (!sku) return res.redirect('/admin/trials?ok=Missing+server');
    const enabled = b.enabled ? true : false;
    const duration_label = (b.duration_label || '').trim();
    const duration_hours = parseInt(b.duration_hours, 10) || 24;
    let max = parseInt(b.max_per_customer, 10); if (!(max >= 1)) max = 1;
    const bp = (await pool.query('SELECT name FROM bot_products WHERE sku=$1', [sku])).rows[0] || {};
    await pool.query(
      `INSERT INTO trial_servers(sku,name,enabled,duration_label,duration_hours,max_per_customer,updated_at)
       VALUES($1,$2,$3,$4,$5,$6,now())
       ON CONFLICT(sku) DO UPDATE SET name=EXCLUDED.name, enabled=EXCLUDED.enabled,
         duration_label=EXCLUDED.duration_label, duration_hours=EXCLUDED.duration_hours,
         max_per_customer=EXCLUDED.max_per_customer, updated_at=now()`,
      [sku, bp.name || sku, enabled, duration_label, duration_hours, max]);
    res.redirect('/admin/trials?ok=' + encodeURIComponent('Saved: ' + (bp.name || sku)));
  });

  return router;
};
