'use strict';
/* Admin — Reports & analytics (real GSZ data from orders/products/customers).
   Stat cards (today / week / month / all-time sales + orders, total customers,
   open orders), a revenue+orders business graph over selectable ranges, Top
   Products and Top Customers. Admin-only. Read-only; touches nothing else. */
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  const PAID = "status IN ('approved','delivering','delivered')";
  const OPEN = "status IN ('pending','verifying')";

  async function loadStats() {
    const r = (await pool.query(
      `SELECT
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND created_at::date=current_date)                                   AS today_rev,
        (SELECT count(*)::int FROM orders WHERE created_at::date=current_date)                                                                     AS today_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND created_at::date=current_date-1)                                 AS yday_rev,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND created_at >= date_trunc('week',now()))                          AS week_rev,
        (SELECT count(*)::int FROM orders WHERE created_at >= date_trunc('week',now()))                                                            AS week_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND created_at >= date_trunc('week',now())-interval '7 days' AND created_at < date_trunc('week',now())) AS lastweek_rev,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND created_at >= date_trunc('month',now()))                         AS month_rev,
        (SELECT count(*)::int FROM orders WHERE created_at >= date_trunc('month',now()))                                                           AS month_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND created_at >= date_trunc('month',now())-interval '1 month' AND created_at < date_trunc('month',now())) AS lastmonth_rev,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID})                                                                     AS all_rev,
        (SELECT count(*)::int FROM orders WHERE ${PAID})                                                                                           AS all_orders,
        (SELECT count(*)::int FROM customers)                                                                                                      AS customers,
        (SELECT count(*)::int FROM orders WHERE ${OPEN})                                                                                           AS open_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${OPEN})                                                                     AS open_value
      `)).rows[0];
    return r;
  }

  async function topProducts() {
    return (await pool.query(
      `SELECT COALESCE(NULLIF(product_name,''),'(unnamed)') AS name, count(*)::int AS sold, COALESCE(sum(amount_pkr),0)::bigint AS rev
         FROM orders WHERE ${PAID} GROUP BY 1 ORDER BY rev DESC, sold DESC LIMIT 8`)).rows;
  }
  async function topCustomers() {
    return (await pool.query(
      `SELECT COALESCE(c.name, o.email, '(guest)') AS name, count(*)::int AS orders, COALESCE(sum(o.amount_pkr),0)::bigint AS spend
         FROM orders o LEFT JOIN customers c ON c.id = o.customer_id
        WHERE ${PAID} AND (o.customer_id IS NOT NULL OR o.email IS NOT NULL)
        GROUP BY 1 ORDER BY spend DESC, orders DESC LIMIT 8`)).rows;
  }

  router.get('/reports', auth, async (req, res) => {
    let stats = {}, prods = [], custs = [];
    try { stats = await loadStats(); } catch (e) {}
    try { prods = await topProducts(); } catch (e) {}
    try { custs = await topCustomers(); } catch (e) {}
    res.render('admin/reports', { active: 'reports', title: 'Reports', stats, prods, custs });
  });

  // Daily revenue + orders series for the graph (gap-filled). range: 14d/1m/3m/6m/1y/all
  router.get('/reports/series.json', auth, async (req, res) => {
    const map = { '14d': 14, '1m': 30, '3m': 90, '6m': 180, '1y': 365 };
    const range = map[req.query.range] ? req.query.range : '14d';
    const sel = `to_char(gs,'YYYY-MM-DD') AS d,
                 COALESCE(sum(o.amount_pkr) FILTER (WHERE ${PAID}),0)::bigint AS rev,
                 count(o.id)::int AS orders`;
    try {
      let rows;
      if (range === 'all') {
        rows = (await pool.query(
          `SELECT ${sel}
             FROM generate_series(COALESCE((SELECT min(created_at)::date FROM orders), current_date), current_date, '1 day') gs
             LEFT JOIN orders o ON o.created_at::date = gs
            GROUP BY gs ORDER BY gs`)).rows;
      } else {
        rows = (await pool.query(
          `SELECT ${sel}
             FROM generate_series(current_date - ($1::int - 1), current_date, '1 day') gs
             LEFT JOIN orders o ON o.created_at::date = gs
            GROUP BY gs ORDER BY gs`, [map[range]])).rows;
      }
      res.json({ ok: true, range, series: rows });
    } catch (e) { res.json({ ok: false, series: [] }); }
  });

  return router;
};
