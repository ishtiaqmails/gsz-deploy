'use strict';
/* Admin — Netflix stock. Screen plans (Phone/TV) are stocked in GSZ's OWN
   inventory (nf_accounts, per plan). Full-account plans are fulfilled from the
   Accounts Portal's free pool (shown live, read-only). Admin-only; no customer
   or checkout behaviour here. */
const express = require('express');
const gate = require('../lib/netflixGate');
const nfPortal = require('../lib/nfPortal');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '256kb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  // Read the portal's free-account counts per product (read-only, fail-safe).
  // NEW portal returns [{ id, old_id, name, free, ... }] — we key by old_id (our stored per-plan id).
  function portalProducts() { return nfPortal.products().then(function (list) { return Array.isArray(list) ? list : []; }).catch(function () { return []; }); }

  async function buildData() {
    const prods = (await pool.query("SELECT id, name FROM products WHERE nf_enabled = true ORDER BY name")).rows;
    const pp = await portalProducts();
    const portalById = {}; pp.forEach(x => { portalById[(x.old_id != null ? x.old_id : x.id)] = x; });
    const out = [];
    for (const pr of prods) {
      const plans = (await pool.query("SELECT id, label, nf_portal_product_id, nf_tier FROM product_plans WHERE product_id=$1 ORDER BY sort, id", [pr.id])).rows;
      const planRows = [];
      for (const pl of plans) {
        const tier = (['phone','tv','full'].indexOf(pl.nf_tier) >= 0 ? pl.nf_tier : gate.tierForPlan(pl.label));
        if (tier === 'full') {
          const pid = pl.nf_portal_product_id;
          const pinfo = pid != null ? portalById[pid] : null;
          planRows.push({ id: pl.id, label: pl.label, tier, full: true, portal_product_id: pid, portalFree: pinfo ? pinfo.free : null, portalName: pinfo ? pinfo.name : null });
        } else {
          const units = (await pool.query(
            "SELECT n.id, n.account_email, n.credentials, (EXISTS(SELECT 1 FROM nf_assignments a WHERE a.nf_account_id=n.id AND a.status='active')) AS assigned FROM nf_accounts n WHERE n.plan_id=$1 ORDER BY n.id DESC", [pl.id])).rows;
          const free = units.filter(u => !u.assigned).length;
          planRows.push({ id: pl.id, label: pl.label, tier, full: false, units, free, assigned: units.length - free });
        }
      }
      out.push({ product: pr, plans: planRows });
    }
    return { data: out, portalProducts: pp };
  }

  router.get('/netflix', auth, async (req, res) => {
    let built = { data: [], portalProducts: [] };
    try { built = await buildData(); } catch (e) { /* show empty on error */ }
    res.render('admin/netflix', { data: built.data, portalProducts: built.portalProducts, flash: req.query.ok || null, active: 'netflix', title: 'Netflix stock' });
  });

  // Add one screen-stock unit to a plan's own inventory.
  router.post('/netflix/stock/add', auth, body, async (req, res) => {
    const b = req.body || {};
    const planId = parseInt(b.plan_id, 10);
    const productId = parseInt(b.product_id, 10);
    const email = String(b.account_email || '').trim();
    if (!planId || !email) return res.redirect('/admin/netflix?ok=' + encodeURIComponent('Email and plan are required'));
    const creds = { email: email, password: String(b.password || '').trim(), profile: String(b.profile || '').trim(), pin: String(b.pin || '').trim() };
    try {
      await pool.query("INSERT INTO nf_accounts(account_email, credentials, product_id, plan_id, status) VALUES($1,$2,$3,$4,'active')", [email, JSON.stringify(creds), productId || null, planId]);
      res.redirect('/admin/netflix?ok=' + encodeURIComponent('Stock added'));
    } catch (e) { res.redirect('/admin/netflix?ok=' + encodeURIComponent('Could not add stock')); }
  });

  // Delete a FREE stock unit (never removes an assigned one).
  router.post('/netflix/stock/:id/delete', auth, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    try {
      const assigned = (await pool.query("SELECT 1 FROM nf_assignments WHERE nf_account_id=$1 AND status='active' LIMIT 1", [id])).rows[0];
      if (assigned) return res.redirect('/admin/netflix?ok=' + encodeURIComponent('That unit is assigned — cannot delete'));
      await pool.query("DELETE FROM nf_accounts WHERE id=$1", [id]);
    } catch (e) {}
    res.redirect('/admin/netflix?ok=' + encodeURIComponent('Stock removed'));
  });

  // Set which portal product a FULL-account plan draws from.
  router.get('/netflix/portal-products.json', auth, async (req, res) => { try { res.json({ ok: true, products: await portalProducts() }); } catch (e) { res.json({ ok: true, products: [] }); } });
  router.post('/netflix/plan/:id/portal', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const pid = String(req.body.portal_product_id || '').trim();
    const val = pid === '' ? null : (parseInt(pid, 10) || null);
    try { await pool.query("UPDATE product_plans SET nf_portal_product_id=$1 WHERE id=$2", [val, id]); } catch (e) {}
    res.redirect('/admin/netflix?ok=' + encodeURIComponent('Portal product set'));
  });

  router.post('/netflix/plan/:id/tier', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const t = String(req.body.tier || '').trim().toLowerCase();
    const val = ['phone', 'tv', 'full'].indexOf(t) >= 0 ? t : null;
    try { await pool.query("UPDATE product_plans SET nf_tier=$1 WHERE id=$2", [val, id]); } catch (e) {}
    res.redirect('/admin/netflix?ok=' + encodeURIComponent('Tier updated'));
  });

  return router;
};
