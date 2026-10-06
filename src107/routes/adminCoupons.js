const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  const toDTLocal = d => { if (!d) return ''; const x = new Date(d); if (isNaN(x)) return ''; const p = n => (n < 10 ? '0' : '') + n; return x.getFullYear() + '-' + p(x.getMonth() + 1) + '-' + p(x.getDate()) + 'T' + p(x.getHours()) + ':' + p(x.getMinutes()); };

  router.get('/coupons', auth, async (req, res) => {
    const rows = (await pool.query('SELECT * FROM coupons ORDER BY featured DESC, id DESC')).rows;
    let edit = null;
    if (req.query.edit) edit = (await pool.query('SELECT * FROM coupons WHERE id=$1', [parseInt(req.query.edit, 10) || 0])).rows[0] || null;
    res.render('admin/coupons', { rows, edit, toDTLocal, flash: req.query.ok || null });
  });

  router.post('/coupons/save', auth, body, async (req, res) => {
    const b = req.body; const id = parseInt(b.id, 10) || 0;
    const code = String(b.code || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!code) return res.redirect('/admin/coupons?ok=Code+required');
    const kind = (b.kind === 'fixed') ? 'fixed' : 'percent';
    const value = parseFloat(b.value) || 0;
    const min = parseFloat(b.min_order_pkr) || 0;
    const maxd = b.max_discount_pkr ? parseFloat(b.max_discount_pkr) : null;
    const exp = b.expires_at ? new Date(b.expires_at) : null;
    const limit = b.usage_limit ? parseInt(b.usage_limit, 10) : null;
    const active = b.active ? true : false;
    const featured = b.featured ? true : false;
    try {
      if (featured) await pool.query('UPDATE coupons SET featured=false WHERE featured=true');
      if (id) {
        await pool.query('UPDATE coupons SET code=$1,kind=$2,value=$3,min_order_pkr=$4,max_discount_pkr=$5,expires_at=$6,usage_limit=$7,active=$8,featured=$9 WHERE id=$10',
          [code, kind, value, min, maxd, exp, limit, active, featured, id]);
      } else {
        await pool.query('INSERT INTO coupons(code,kind,value,min_order_pkr,max_discount_pkr,expires_at,usage_limit,active,featured) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)',
          [code, kind, value, min, maxd, exp, limit, active, featured]);
      }
      res.redirect('/admin/coupons?ok=' + encodeURIComponent('Saved ' + code));
    } catch (e) { res.redirect('/admin/coupons?ok=' + encodeURIComponent(String(e.message).indexOf('duplicate') >= 0 ? 'That code already exists' : 'Save failed')); }
  });

  router.post('/coupons/:id/toggle', auth, async (req, res) => { await pool.query('UPDATE coupons SET active=NOT active WHERE id=$1', [req.params.id]); res.redirect('/admin/coupons?ok=Updated'); });
  router.post('/coupons/:id/feature', auth, async (req, res) => { await pool.query('UPDATE coupons SET featured=false WHERE featured=true'); await pool.query('UPDATE coupons SET featured=true, active=true WHERE id=$1', [req.params.id]); res.redirect('/admin/coupons?ok=Shown+on+promo+bar'); });
  router.post('/coupons/:id/unfeature', auth, async (req, res) => { await pool.query('UPDATE coupons SET featured=false WHERE id=$1', [req.params.id]); res.redirect('/admin/coupons?ok=Removed+from+promo+bar'); });
  router.post('/coupons/:id/delete', auth, async (req, res) => { await pool.query('DELETE FROM coupons WHERE id=$1', [req.params.id]); res.redirect('/admin/coupons?ok=Deleted'); });

  return router;
};
