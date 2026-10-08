const path = require('path');
const fs = require('fs');
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const deliver = require('../lib/deliver')(pool);
  const UP = path.join(__dirname, '..', 'uploads', 'proofs');

  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  router.get('/orders', auth, async (req, res) => {
    try {
      const status = String(req.query.status || '');
      const q = String(req.query.q || '').trim();
      const conds = [], params = [];
      if (status) { params.push(status); conds.push('status=$' + params.length); }
      if (q) { params.push('%' + q.toLowerCase() + '%'); conds.push('(lower(order_no) LIKE $' + params.length + ' OR lower(email) LIKE $' + params.length + ' OR lower(whatsapp) LIKE $' + params.length + ' OR lower(product_name) LIKE $' + params.length + ')'); }
      const where = conds.length ? ('WHERE ' + conds.join(' AND ')) : '';
      const perPage = 50;
      const total = (await pool.query(`SELECT count(*)::int n FROM orders ${where}`, params)).rows[0].n;
      const pages = Math.max(1, Math.ceil(total / perPage));
      let page = parseInt(req.query.page, 10) || 1; if (page < 1) page = 1; if (page > pages) page = pages;
      const rows = (await pool.query(
        `SELECT id, order_no, status, email, whatsapp, product_name, plan_label, currency, amount_display, amount_pkr, method_name, created_at
         FROM orders ${where} ORDER BY id DESC LIMIT ${perPage} OFFSET ${(page - 1) * perPage}`, params)).rows;
      const counts = (await pool.query('SELECT status, count(*)::int n FROM orders GROUP BY status')).rows
        .reduce((a, r) => { a[r.status] = r.n; return a; }, {});
      const agg = (await pool.query(
        "SELECT count(*)::int grand, " +
        "COALESCE(sum(amount_pkr) FILTER (WHERE status IN ('approved','delivering','delivered') AND date_trunc('month',created_at)=date_trunc('month',now())),0) rev_month " +
        "FROM orders")).rows[0];
      res.render('admin/orders', { rows, counts, agg, status, q, page, pages, total, flash: req.query.ok || null });
    } catch (e) { res.status(500).send('Orders error: ' + e.message); }
  });

  router.get('/orders/proof/:file', auth, (req, res) => {
    const f = path.basename(String(req.params.file || ''));
    const fp = path.join(UP, f);
    if (!f || !fp.startsWith(UP) || !fs.existsSync(fp)) return res.status(404).send('Not found');
    res.sendFile(fp);
  });

  router.get('/orders/:id', auth, async (req, res) => {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE id=$1', [req.params.id])).rows[0];
      if (!o) return res.redirect('/admin/orders?ok=Order+not+found');
      const m = (await pool.query('SELECT name, details, instructions, currency FROM payment_methods WHERE key=$1', [o.method_key])).rows[0] || {};
      res.render('admin/order_detail', { o, method: m, flash: req.query.ok || null });
    } catch (e) { res.status(500).send('Order detail error: ' + e.message); }
  });

  const ALLOW = ['pending', 'paid', 'approved', 'delivered', 'rejected', 'cancelled'];
  router.post('/orders/:id/status', auth, express.urlencoded({ extended: false }), async (req, res) => {
    try {
      const st = String((req.body || {}).status || '');
      if (!ALLOW.includes(st)) return res.redirect('/admin/orders/' + req.params.id + '?ok=Invalid+status');
      if (st === 'delivered') {
        try { await deliver.markDelivered(parseInt(req.params.id, 10), { credentials: (req.body || {}).delivered_credentials || '' }); }
        catch (e) { await pool.query("UPDATE orders SET status='delivered', delivered_at=COALESCE(delivered_at, now()) WHERE id=$1", [req.params.id]); }
        return res.redirect('/admin/orders/' + req.params.id + '?ok=' + encodeURIComponent('Delivered — customer notified'));
      }
      await pool.query('UPDATE orders SET status=$1 WHERE id=$2', [st, req.params.id]);
      res.redirect('/admin/orders/' + req.params.id + '?ok=Status+updated');
    } catch (e) { res.status(500).send('Status error: ' + e.message); }
  });

  return router;
};
