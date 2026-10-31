'use strict';
/* Admin restock-waitlist detail (Stage: waitlist drill-down). Lists who is waiting for which
   out-of-stock product/plan — the dashboard only showed a count. Read-only + a "remove" that
   cancels one waiter (non-destructive: status='cancelled'). */
const express = require('express');
module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  router.get('/waitlist', auth, async (req, res) => {
    let rows = [];
    try {
      rows = (await pool.query(
        "SELECT w.id, w.product_name, w.plan_label, w.email, w.whatsapp, w.status, w.notified_at, c.name AS customer_name " +
        "FROM restock_waitlist w LEFT JOIN customers c ON c.id = w.customer_id " +
        "WHERE w.status = 'pending' ORDER BY w.product_name, w.plan_label, w.id")).rows;
    } catch (e) { /* table/columns guard */ }
    res.render('admin/waitlist', { rows, title: 'Restock waitlist', flash: req.query.ok || null });
  });

  router.post('/waitlist/remove', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const id = parseInt(req.body && req.body.id, 10);
    if (id) { try { await pool.query("UPDATE restock_waitlist SET status='cancelled' WHERE id=$1", [id]); } catch (e) {} }
    res.redirect('/admin/waitlist?ok=' + encodeURIComponent('Removed from waitlist'));
  });

  return router;
};
