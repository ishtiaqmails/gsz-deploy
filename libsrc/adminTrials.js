const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  // ---- Trials home: 3 stat cards + server config + per-customer activity ----
  router.get('/trials', auth, async (req, res) => {
    const q = (req.query.q || '').trim();
    let rows = [], activity = [], stats = { active: 0, total: 0, atlimit: 0 };
    try {
      // server config (IPTV bot products <- trial_servers), with linked storefront product
      rows = (await pool.query(
        `SELECT bp.sku, bp.name, ts.enabled, ts.duration_label, ts.duration_hours, ts.max_per_customer,
                (SELECT string_agg(DISTINCT pr.name, ', ') FROM product_plans pp JOIN products pr ON pr.id = pp.product_id WHERE pp.bot_sku = bp.sku) AS store_products
         FROM bot_products bp LEFT JOIN trial_servers ts ON ts.sku = bp.sku
         WHERE lower(coalesce(bp.delivery_type,'')) = 'iptv'
         ORDER BY bp.name`)).rows;
    } catch (e) { rows = []; }

    try {
      const r1 = await pool.query("SELECT count(*)::int AS total, count(*) FILTER (WHERE status='active')::int AS active FROM trial_claims");
      stats.total = r1.rows[0].total; stats.active = r1.rows[0].active;
      const r2 = await pool.query(
        `SELECT count(*)::int AS n FROM (
           SELECT tc.customer_id, tc.trial_type, coalesce(max(ts.max_per_customer),1) mx,
                  count(*) FILTER (WHERE tc.status='active') ua
           FROM trial_claims tc LEFT JOIN trial_servers ts ON ts.sku = tc.trial_type
           GROUP BY tc.customer_id, tc.trial_type
         ) g WHERE g.ua >= g.mx AND g.ua > 0`);
      stats.atlimit = r2.rows[0].n;
    } catch (e) {}

    try {
      const params = [];
      let where = '';
      if (q) { params.push('%' + q + '%'); where = `WHERE (c.name ILIKE $1 OR c.email ILIKE $1 OR coalesce(ts.name,tc.server_name,tc.trial_type) ILIKE $1)`; }
      activity = (await pool.query(
        `SELECT tc.customer_id, tc.trial_type AS sku, c.name, c.email,
                coalesce(ts.name, max(tc.server_name), tc.trial_type) AS server,
                coalesce(max(ts.max_per_customer),1)::int AS max_allowed,
                count(*) FILTER (WHERE tc.status='active')::int AS used_active,
                count(*)::int AS total_claims,
                max(tc.claimed_at) AS last_claimed
         FROM trial_claims tc
         JOIN customers c ON c.id = tc.customer_id
         LEFT JOIN trial_servers ts ON ts.sku = tc.trial_type
         ${where}
         GROUP BY tc.customer_id, tc.trial_type, c.name, c.email, ts.name
         ORDER BY max(tc.claimed_at) DESC
         LIMIT 300`, params)).rows;
    } catch (e) { activity = []; }

    res.render('admin/trials', { rows, activity, stats, q, flash: req.query.ok || null });
  });

  // ---- Save one server's trial config ----
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

  // ---- Reset one customer's trial limit for one IPTV (frees the quota) ----
  router.post('/trials/reset', auth, body, async (req, res) => {
    const customer_id = parseInt(req.body.customer_id, 10);
    const sku = (req.body.sku || '').trim();
    if (!customer_id || !sku) return res.redirect('/admin/trials?ok=Nothing+to+reset#activity');
    let freed = 0;
    try {
      const r = await pool.query(
        `UPDATE trial_claims
           SET status='reset',
               metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('reset_at', now()::text, 'reset_by', 'admin')
         WHERE customer_id=$1 AND trial_type=$2 AND status IN ('active','pending')`,
        [customer_id, sku]);
      freed = r.rowCount || 0;
    } catch (e) {}
    res.redirect('/admin/trials?ok=' + encodeURIComponent('Trial limit reset — ' + freed + ' freed') + '#activity');
  });

  return router;
};
