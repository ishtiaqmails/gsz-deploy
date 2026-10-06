'use strict';
/* Account cart sync — merges the browser (guest) cart into the signed-in
   customer's saved cart and serves it back, so carts persist and follow the
   customer across devices. Merge is idempotent (max qty per line). */
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const json = express.json({ limit: '128kb' });
  function authed(req) { return !!(req.session && req.session.customer); }

  const key = it => String(it.slug || '') + '|' + String(it.planIdx) + '|' + String(it.type || '');
  function clean(items) {
    if (!Array.isArray(items)) return [];
    return items.slice(0, 50).map(it => ({
      slug: String(it.slug || '').slice(0, 120), name: String(it.name || '').slice(0, 160),
      img: String(it.img || '').slice(0, 200), planIdx: parseInt(it.planIdx, 10) || 0,
      planLabel: String(it.planLabel || '').slice(0, 120),
      pricePkr: Number(it.pricePkr) || 0, type: String(it.type || '').slice(0, 60),
      typeLabel: String(it.typeLabel || '').slice(0, 120), qty: Math.max(1, Math.min(99, parseInt(it.qty, 10) || 1))
    })).filter(it => it.slug);
  }
  function merge(a, b) {
    const m = {};
    [].concat(a || [], b || []).forEach(it => {
      const k = key(it);
      if (!m[k]) m[k] = Object.assign({}, it);
      else m[k].qty = Math.max(Number(m[k].qty) || 1, Number(it.qty) || 1);
    });
    return Object.keys(m).map(k => m[k]);
  }

  router.get('/api/cart', async (req, res) => {
    if (!authed(req)) return res.json({ items: [] });
    try {
      const r = (await pool.query('SELECT items FROM customer_carts WHERE customer_id=$1', [req.session.customer.id])).rows[0];
      res.json({ items: (r && r.items) ? r.items : [] });
    } catch (e) { res.json({ items: [] }); }
  });

  router.post('/api/cart/sync', json, async (req, res) => {
    if (!authed(req)) return res.json({ items: clean(req.body && req.body.items) });
    const cid = req.session.customer.id;
    try {
      const incoming = clean(req.body && req.body.items);
      const stored = (await pool.query('SELECT items FROM customer_carts WHERE customer_id=$1', [cid])).rows[0];
      const merged = merge(stored && stored.items ? stored.items : [], incoming);
      await pool.query(
        `INSERT INTO customer_carts(customer_id, items, updated_at) VALUES($1,$2,now())
         ON CONFLICT(customer_id) DO UPDATE SET items=$2, updated_at=now()`,
        [cid, JSON.stringify(merged)]);
      res.json({ items: merged });
    } catch (e) { res.json({ items: clean(req.body && req.body.items) }); }
  });

  return router;
};
