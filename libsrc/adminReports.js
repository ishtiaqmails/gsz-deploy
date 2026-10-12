'use strict';
/* Admin — Reports & analytics (complete). Real GSZ data, Asia/Karachi timezone.
   KPI cards (today/week/month/all-time rev+orders with trends, customers, open orders),
   business graph (range-switchable), Top Products, Top Customers, Low Stock, Smart Insights,
   Order Heatmap (hour x day-of-week), Payment-method / weekday / hour distributions,
   Customer mix, Cumulative revenue (30d), Order-status funnel (30d). Read-only; touches nothing else. */
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  const PAID = "status IN ('approved','delivering','delivered')";
  const OPEN = "status IN ('pending','verifying')";
  const LC   = "(created_at AT TIME ZONE 'Asia/Karachi')";   // order time in PKT (naive ts)
  const PNOW = "(now() AT TIME ZONE 'Asia/Karachi')";        // now in PKT (naive ts)

  async function loadStats() {
    return (await pool.query(
      `SELECT
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND ${LC}::date = ${PNOW}::date)                                     AS today_rev,
        (SELECT count(*)::int FROM orders WHERE ${LC}::date = ${PNOW}::date)                                                                       AS today_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND ${LC}::date = ${PNOW}::date - 1)                                 AS yday_rev,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND ${LC} >= date_trunc('week',${PNOW}))                             AS week_rev,
        (SELECT count(*)::int FROM orders WHERE ${LC} >= date_trunc('week',${PNOW}))                                                               AS week_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND ${LC} >= date_trunc('week',${PNOW}) - interval '7 days' AND ${LC} < date_trunc('week',${PNOW})) AS lastweek_rev,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND ${LC} >= date_trunc('month',${PNOW}))                            AS month_rev,
        (SELECT count(*)::int FROM orders WHERE ${LC} >= date_trunc('month',${PNOW}))                                                              AS month_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID} AND ${LC} >= date_trunc('month',${PNOW}) - interval '1 month' AND ${LC} < date_trunc('month',${PNOW})) AS lastmonth_rev,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${PAID})                                                                     AS all_rev,
        (SELECT count(*)::int FROM orders WHERE ${PAID})                                                                                           AS all_orders,
        (SELECT count(*)::int FROM customers)                                                                                                      AS customers,
        (SELECT count(*)::int FROM orders WHERE ${OPEN})                                                                                           AS open_orders,
        (SELECT COALESCE(sum(amount_pkr),0)::bigint FROM orders WHERE ${OPEN})                                                                     AS open_value
      `)).rows[0];
  }

  async function topProducts() {
    return (await pool.query(
      `SELECT COALESCE(NULLIF(product_name,''),'(unnamed)') AS name, count(*)::int AS sold, COALESCE(sum(amount_pkr),0)::bigint AS rev
         FROM orders WHERE ${PAID} GROUP BY 1 ORDER BY rev DESC, sold DESC LIMIT 10`)).rows;
  }
  async function topCustomers() {
    return (await pool.query(
      `SELECT COALESCE(c.name, o.email, '(guest)') AS name, count(*)::int AS orders, COALESCE(sum(o.amount_pkr),0)::bigint AS spend
         FROM orders o LEFT JOIN customers c ON c.id = o.customer_id
        WHERE ${PAID} AND (o.customer_id IS NOT NULL OR o.email IS NOT NULL)
        GROUP BY 1 ORDER BY spend DESC, orders DESC LIMIT 10`)).rows;
  }
  async function lowStock() {
    const rows = (await pool.query(
      `SELECT pr.name AS product, pl.label AS plan,
              (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status='available') AS avail
         FROM product_plans pl JOIN products pr ON pr.id = pl.product_id
        WHERE pl.source='inventory'
        ORDER BY avail ASC, pr.name
        LIMIT 60`)).rows;
    return rows.filter(r => Number(r.avail) <= 5).slice(0, 10);
  }
  async function heatmap() {
    return (await pool.query(
      `SELECT EXTRACT(dow FROM ${LC})::int AS dow, EXTRACT(hour FROM ${LC})::int AS hr, count(*)::int AS n
         FROM orders WHERE ${LC} >= ${PNOW} - interval '30 days' GROUP BY 1,2`)).rows;
  }
  async function payMix() {
    return (await pool.query(
      `SELECT COALESCE(NULLIF(method_name,''),'Other') AS name, count(*)::int AS n, COALESCE(sum(amount_pkr),0)::bigint AS rev
         FROM orders WHERE ${PAID} GROUP BY 1 ORDER BY n DESC LIMIT 8`)).rows;
  }
  async function custMix() {
    return (await pool.query(
      `SELECT count(*) FILTER (WHERE customer_id IS NOT NULL)::int AS registered,
              count(*) FILTER (WHERE customer_id IS NULL)::int AS guest
         FROM orders WHERE ${PAID}`)).rows[0];
  }
  async function funnel() {
    return (await pool.query(
      `SELECT count(*)::int AS placed,
              count(*) FILTER (WHERE ${PAID})::int AS paid,
              count(*) FILTER (WHERE status='delivered')::int AS delivered
         FROM orders WHERE ${LC} >= ${PNOW} - interval '30 days'`)).rows[0];
  }
  async function cumulative() {
    return (await pool.query(
      `SELECT to_char(gs,'YYYY-MM-DD') AS d, COALESCE(sum(o.amount_pkr) FILTER (WHERE ${PAID}),0)::bigint AS rev
         FROM generate_series((${PNOW})::date - 29, (${PNOW})::date, '1 day') gs
         LEFT JOIN orders o ON (o.created_at AT TIME ZONE 'Asia/Karachi')::date = gs
        GROUP BY gs ORDER BY gs`)).rows;
  }
  async function peaks() {
    let hr = null, dw = null;
    try { hr = (await pool.query(`SELECT EXTRACT(hour FROM ${LC})::int AS hr, count(*)::int AS n FROM orders WHERE ${LC} >= ${PNOW} - interval '90 days' GROUP BY 1 ORDER BY n DESC NULLS LAST LIMIT 1`)).rows[0]; } catch (e) {}
    try { dw = (await pool.query(`SELECT EXTRACT(dow FROM ${LC})::int AS dow, count(*)::int AS n FROM orders WHERE ${LC} >= ${PNOW} - interval '90 days' GROUP BY 1 ORDER BY n DESC NULLS LAST LIMIT 1`)).rows[0]; } catch (e) {}
    return { hr: hr ? hr.hr : null, dow: dw ? dw.dow : null };
  }

  router.get('/reports', auth, async (req, res) => {
    const d = { stats: {}, prods: [], custs: [], low: [], heat: [], pay: [], mix: { registered: 0, guest: 0 }, fun: { placed: 0, paid: 0, delivered: 0 }, cum: [], peak: { hr: null, dow: null } };
    try { d.stats = await loadStats(); } catch (e) {}
    try { d.prods = await topProducts(); } catch (e) {}
    try { d.custs = await topCustomers(); } catch (e) {}
    try { d.low = await lowStock(); } catch (e) {}
    try { d.heat = await heatmap(); } catch (e) {}
    try { d.pay = await payMix(); } catch (e) {}
    try { d.mix = await custMix(); } catch (e) {}
    try { d.fun = await funnel(); } catch (e) {}
    try { d.cum = await cumulative(); } catch (e) {}
    try { d.peak = await peaks(); } catch (e) {}
    res.render('admin/reports', Object.assign({ active: 'reports', title: 'Reports' }, d));
  });

  // Daily revenue + orders series for the business graph (gap-filled, PKT). range: 14d/1m/3m/6m/1y/all
  router.get('/reports/series.json', auth, async (req, res) => {
    const map = { '14d': 14, '1m': 30, '3m': 90, '6m': 180, '1y': 365 };
    const range = map[req.query.range] ? req.query.range : '14d';
    const sel = `to_char(gs,'YYYY-MM-DD') AS d, COALESCE(sum(o.amount_pkr) FILTER (WHERE ${PAID}),0)::bigint AS rev, count(o.id)::int AS orders`;
    const JOIN = `LEFT JOIN orders o ON (o.created_at AT TIME ZONE 'Asia/Karachi')::date = gs`;
    try {
      let rows;
      if (range === 'all') {
        rows = (await pool.query(
          `SELECT ${sel} FROM generate_series(COALESCE((SELECT min(created_at AT TIME ZONE 'Asia/Karachi')::date FROM orders), (${PNOW})::date), (${PNOW})::date, '1 day') gs ${JOIN} GROUP BY gs ORDER BY gs`)).rows;
      } else {
        rows = (await pool.query(
          `SELECT ${sel} FROM generate_series((${PNOW})::date - ($1::int - 1), (${PNOW})::date, '1 day') gs ${JOIN} GROUP BY gs ORDER BY gs`, [map[range]])).rows;
      }
      res.json({ ok: true, range, series: rows });
    } catch (e) { res.json({ ok: false, series: [] }); }
  });

  return router;
};
