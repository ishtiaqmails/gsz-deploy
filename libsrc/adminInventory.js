'use strict';
/* Admin — Own-Inventory engine over inventory_items. SELF-AWARE from the Product page:
   which plans are stocked (plan source='inventory') and each plan's FIELDS
   (product_plans.custom_fields) are both set on the product page. This section only lists
   inventory plans and uses each plan's own fields for the line-aligned bulk Add + Manage.
   Checkout auto-fulfils source='inventory' plans (takes one available unit, delivers its
   payload, marks it sold). Admin-only. */
const express = require('express');
const EMAIL_RE = /[^\s,|;]+@[^\s,|;]+\.[^\s,|;]+/;

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '4mb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  const back = (res, m, to) => res.redirect((to || '/admin/inventory') + (to && to.indexOf('?') >= 0 ? '&' : '?') + 'ok=' + encodeURIComponent(m));
  function idList(b) { let v = b.ids; if (!v) return []; if (!Array.isArray(v)) v = [v]; return v.map(x => parseInt(x, 10)).filter(Boolean); }
  // fields come from product_plans.custom_fields: [{label:"Email"},...] (or plain strings)
  function planFields(row) {
    try {
      const f = row.custom_fields; const a = Array.isArray(f) ? f : JSON.parse(f || '[]');
      return a.map(x => (x && typeof x === 'object') ? String(x.label || x.key || '').trim() : String(x).trim()).filter(Boolean);
    } catch (e) { return []; }
  }
  function renderPayload(fieldNames, vals) { return fieldNames.map(fn => fn + ': ' + (vals[fn] || '')).join('\n'); }
  function pickRef(fieldNames, vals) {
    for (const fn of fieldNames) { if (/mail|email/i.test(fn) && vals[fn]) return String(vals[fn]).trim(); }
    for (const fn of fieldNames) { const m = String(vals[fn] || '').match(EMAIL_RE); if (m) return m[0]; }
    return null;
  }

  // ---------- LIST (only inventory-source plans, grouped by product) ----------
  async function loadList() {
    const prods = (await pool.query(
      `SELECT DISTINCT pr.id, pr.name FROM products pr JOIN product_plans pl ON pl.product_id=pr.id
       WHERE pl.source='inventory' ORDER BY pr.name`)).rows;
    let totUnits = 0, totValue = 0;
    for (const pr of prods) {
      pr.plans = (await pool.query(
        `SELECT pl.id, pl.label, pl.price_pkr, COALESCE(pl.custom_fields,'[]'::jsonb) AS custom_fields,
                (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status='available') AS avail,
                (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status<>'available') AS sold
         FROM product_plans pl WHERE pl.product_id=$1 AND pl.source='inventory' ORDER BY pl.sort, pl.id`, [pr.id])).rows;
      pr.plans.forEach(pl => { pl.fields = planFields(pl); totUnits += pl.avail; totValue += pl.avail * Number(pl.price_pkr || 0); });
    }
    return { prods, stats: { products: prods.length, units: totUnits, value: totValue } };
  }

  router.get('/inventory', auth, async (req, res) => {
    let d = { prods: [], stats: { products: 0, units: 0, value: 0 } };
    try { d = await loadList(); } catch (e) {}
    res.render('admin/inventory', { d, flash: req.query.ok || null, active: 'inventory', title: 'Add Stock' });
  });

  // Bulk add — one textarea per field (col0..colN), line-aligned. Optional ledger.
  router.post('/inventory/add', auth, body, async (req, res) => {
    const planId = parseInt(req.body.plan_id, 10);
    if (!planId) return back(res, 'Missing plan');
    const prow = (await pool.query("SELECT COALESCE(custom_fields,'[]'::jsonb) AS custom_fields FROM product_plans WHERE id=$1 AND source='inventory'", [planId])).rows[0];
    const fieldNames = prow ? planFields(prow) : [];
    if (!fieldNames.length) return back(res, 'Set this plan’s fields on the product page first');
    const cols = fieldNames.map((_, i) => String(req.body['col' + i] || '').split('\n').map(s => s.trim()));
    const n = Math.max.apply(null, cols.map(c => { let k = c.length; while (k > 0 && !c[k - 1]) k--; return k; }).concat([0]));
    if (!n) return back(res, 'Nothing to add');
    const vendor = String(req.body.vendor || '').trim() || null;
    const cost = req.body.cost ? Number(req.body.cost) : null;
    const c = await pool.connect(); let added = 0;
    try {
      await c.query('BEGIN');
      for (let j = 0; j < n && j < 5000; j++) {
        const vals = {}; fieldNames.forEach((fn, i) => { vals[fn] = (cols[i][j] || '').trim(); });
        if (!fieldNames.some(fn => vals[fn])) continue;
        const payload = renderPayload(fieldNames, vals);
        const ref = pickRef(fieldNames, vals);
        await c.query("INSERT INTO inventory_items(plan_id, payload, fields, account_ref, vendor, cost_pkr, status) VALUES($1,$2,$3,$4,$5,$6,'available')",
          [planId, payload, JSON.stringify(vals), ref, vendor, cost]);
        added++;
      }
      await c.query('COMMIT');
    } catch (e) { try { await c.query('ROLLBACK'); } catch (x) {} added = 0; }
    finally { c.release(); }
    back(res, added ? ('Added ' + added + ' unit(s)') : 'Add failed — every box must have the same number of lines');
  });

  // ---------- MANAGE (per plan) ----------
  router.get('/inventory/manage/:planId', auth, async (req, res) => {
    const planId = parseInt(req.params.planId, 10);
    const plan = (await pool.query(
      "SELECT pl.id, pl.label, pl.price_pkr, pl.product_id, pr.name AS product_name, COALESCE(pl.custom_fields,'[]'::jsonb) AS custom_fields FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.id=$1", [planId])).rows[0];
    if (!plan) return res.redirect('/admin/inventory?ok=Plan+not+found');
    plan.fields = planFields(plan);
    const filter = ['all', 'available', 'sold'].indexOf(req.query.f) >= 0 ? req.query.f : 'all';
    const whereF = filter === 'available' ? "AND i.status='available'" : (filter === 'sold' ? "AND i.status<>'available'" : '');
    const items = (await pool.query(
      `SELECT i.id, i.payload, i.fields, i.status, i.order_no, i.vendor, i.cost_pkr, i.created_at, i.delivered_at,
              o.email AS o_email, o.whatsapp AS o_whatsapp
       FROM inventory_items i LEFT JOIN orders o ON o.order_no = i.order_no
       WHERE i.plan_id=$1 ${whereF} ORDER BY (i.status='available') DESC, i.id DESC LIMIT 1000`, [planId])).rows;
    const price = Number(plan.price_pkr || 0);
    const counts = (await pool.query(
      "SELECT count(*) FILTER (WHERE status='available')::int AS avail, count(*) FILTER (WHERE status<>'available')::int AS sold FROM inventory_items WHERE plan_id=$1", [planId])).rows[0];
    const targets = (await pool.query(
      "SELECT pl.id, pr.name||' — '||pl.label AS label FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.source='inventory' AND pl.id<>$1 ORDER BY pr.name, pl.id", [planId])).rows;
    res.render('admin/inventory_manage', { plan, items, filter, price, counts, targets, flash: req.query.ok || null, active: 'inventory', title: 'Stock — ' + plan.label });
  });

  router.post('/inventory/item/:id/edit', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const planId = parseInt(req.body.plan_id, 10);
    const prow = (await pool.query("SELECT COALESCE(custom_fields,'[]'::jsonb) AS custom_fields FROM product_plans WHERE id=$1", [planId])).rows[0];
    const fieldNames = prow ? planFields(prow) : [];
    const vals = {}; fieldNames.forEach((fn, i) => { vals[fn] = String(req.body['f' + i] || '').trim(); });
    const payload = renderPayload(fieldNames, vals); const ref = pickRef(fieldNames, vals);
    try { await pool.query("UPDATE inventory_items SET payload=$1, fields=$2, account_ref=$3 WHERE id=$4 AND status='available'", [payload, JSON.stringify(vals), ref, id]); } catch (e) {}
    back(res, 'Unit updated', '/admin/inventory/manage/' + planId);
  });
  router.post('/inventory/item/:id/delete', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10); const planId = parseInt(req.body.plan_id, 10);
    try { await pool.query("DELETE FROM inventory_items WHERE id=$1 AND status='available'", [id]); } catch (e) {}
    back(res, 'Unit deleted', '/admin/inventory/manage/' + planId);
  });
  router.post('/inventory/bulk-delete', auth, body, async (req, res) => {
    const planId = parseInt(req.body.plan_id, 10); const list = idList(req.body);
    if (list.length) { try { await pool.query("DELETE FROM inventory_items WHERE id=ANY($1) AND status='available'", [list]); } catch (e) {} }
    back(res, 'Deleted ' + list.length + ' selected', '/admin/inventory/manage/' + planId);
  });
  router.post('/inventory/plan/:id/clear', auth, async (req, res) => {
    const planId = parseInt(req.params.id, 10);
    try { await pool.query("DELETE FROM inventory_items WHERE plan_id=$1 AND status='available'", [planId]); } catch (e) {}
    back(res, 'Cleared all available units', '/admin/inventory/manage/' + planId);
  });
  router.post('/inventory/move', auth, body, async (req, res) => {
    const planId = parseInt(req.body.plan_id, 10); const to = parseInt(req.body.to_plan_id, 10); const list = idList(req.body);
    if (list.length && to) { try { await pool.query("UPDATE inventory_items SET plan_id=$1 WHERE id=ANY($2) AND status='available'", [to, list]); } catch (e) {} }
    back(res, 'Moved ' + list.length + ' unit(s)', '/admin/inventory/manage/' + planId);
  });

  return router;
};
