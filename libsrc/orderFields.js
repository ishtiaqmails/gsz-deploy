'use strict';
/* GET /account/tools/order-fields/:no — returns the structured bot `fields` for one delivered
   order so the hub can render the premium credentials card. Owner-checked, fail-safe.
   Lazy capture: if not stored yet, fetch once from the bot and cache in orders.bot_fields. */
const express = require('express');
let botapi = null; try { botapi = require('../lib/botapi'); } catch (e) { botapi = null; }

module.exports = function (pool) {
  const router = express.Router();
  function requireLogin(req, res, next) {
    if (req.session && req.session.customer) return next();
    return res.status(401).json({ ok: false, reason: 'login' });
  }
  router.get('/account/tools/order-fields/:no', requireLogin, async (req, res) => {
    try {
      const c = req.session.customer; const no = String(req.params.no || '');
      const o = (await pool.query(
        "SELECT id, order_no, source, status, bot_fields FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1",
        [no, c.id, c.email])).rows[0];
      if (!o) return res.json({ ok: true, fields: null });
      const done = ['delivered', 'completed', 'done'].indexOf(String(o.status || '').toLowerCase()) >= 0;
      if (!done) return res.json({ ok: true, fields: null });
      let f = o.bot_fields; if (typeof f === 'string') { try { f = JSON.parse(f); } catch (e) { f = null; } }
      if ((!f || !f.delivery_type) && o.source === 'bot' && botapi && botapi.configured && botapi.configured()) {
        try {
          const st = await botapi.orderStatus(o.order_no);
          if (st && st.fields && st.fields.delivery_type) {
            f = st.fields;
            await pool.query("UPDATE orders SET bot_fields=$1 WHERE id=$2", [JSON.stringify(f), o.id]);
          }
        } catch (e) { /* bot unreachable — hub falls back to raw text */ }
      }
      return res.json({ ok: true, fields: (f && f.delivery_type) ? f : null });
    } catch (e) { return res.json({ ok: true, fields: null }); }
  });
  return router;
};
