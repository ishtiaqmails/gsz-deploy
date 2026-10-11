'use strict';
/* Admin — Customers (GSZ). Real customers only; GSZ has no wallet/VIP/types, so this
   mirrors the reseller Customers layout with GSZ's own fields: identity, WhatsApp +
   email verification, order count, join date. Premium mobile + desktop model.
   Routes: list (+ stats), detail JSON (recent orders), block/unblock (enforced at
   login), delete (keeps order history, clears auth links). Admin-only. */
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '1mb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  const back = (res, m) => res.redirect('/admin/customers?ok=' + encodeURIComponent(m));

  // orders tie to a customer by id, or by email when the order was placed signed-out
  const OMATCH = "(o.customer_id=c.id OR (o.customer_id IS NULL AND o.email IS NOT NULL AND lower(o.email)=lower(c.email)))";

  async function loadList() {
    const rows = (await pool.query(
      `SELECT c.id, c.name, c.email, c.email_verified, c.wa_number, c.wa_verified, c.blocked,
              c.created_at, c.last_login,
              (SELECT count(*)::int FROM orders o WHERE ${OMATCH}) AS orders
         FROM customers c
        ORDER BY c.id DESC`)).rows;
    const stats = (await pool.query(
      `SELECT count(*)::int total,
              count(*) FILTER (WHERE wa_verified)::int wa,
              count(*) FILTER (WHERE email_verified)::int em,
              count(*) FILTER (WHERE blocked)::int blk
         FROM customers`)).rows[0] || { total: 0, wa: 0, em: 0, blk: 0 };
    return { rows, stats };
  }

  router.get('/customers', auth, async (req, res) => {
    let d = { rows: [], stats: { total: 0, wa: 0, em: 0, blk: 0 } };
    try { d = await loadList(); } catch (e) {}
    res.render('admin/customers', { d, flash: req.query.ok || null, active: 'customers', title: 'Customers' });
  });

  // Detail for the view modal (customer + verified WhatsApp phone + recent orders)
  router.get('/customers/:id.json', auth, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    try {
      const c = (await pool.query(
        `SELECT id, name, email, email_verified, wa_number, wa_verified, blocked, created_at, last_login, ref_code
           FROM customers WHERE id=$1`, [id])).rows[0];
      if (!c) return res.status(404).json({ error: 'not found' });
      let phone = '';
      try {
        const L = (await pool.query(
          "SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1",
          [id])).rows[0];
        if (L) phone = L.current_phone_e164 || '';
      } catch (e) {}
      const orders = (await pool.query(
        `SELECT order_no, status, product_name, plan_label, amount_display, currency, created_at
           FROM orders o
          WHERE o.customer_id=$1 OR (o.customer_id IS NULL AND o.email IS NOT NULL AND lower(o.email)=lower($2))
          ORDER BY id DESC LIMIT 12`, [id, c.email])).rows;
      res.json({ c, phone, orders });
    } catch (e) { res.status(500).json({ error: 'server' }); }
  });

  function idList(b) { let v = b.ids; if (!v) return []; if (!Array.isArray(v)) v = [v]; return v.map(x => parseInt(x, 10)).filter(Boolean); }

  // Bulk: block / unblock / delete selected
  router.post('/customers/bulk', auth, body, async (req, res) => {
    const action = String(req.body.action || '');
    const ids = idList(req.body);
    if (!ids.length) return back(res, 'Nothing selected');
    if (action === 'block') {
      try { await pool.query('UPDATE customers SET blocked=true WHERE id=ANY($1)', [ids]); } catch (e) {}
      return back(res, 'Blocked ' + ids.length + ' customer(s)');
    }
    if (action === 'unblock') {
      try { await pool.query('UPDATE customers SET blocked=false WHERE id=ANY($1)', [ids]); } catch (e) {}
      return back(res, 'Unblocked ' + ids.length + ' customer(s)');
    }
    if (action === 'delete') {
      for (const q of [
        'UPDATE orders SET customer_id=NULL WHERE customer_id=ANY($1)',
        'DELETE FROM customer_tokens WHERE customer_id=ANY($1)',
        'DELETE FROM customer_carts WHERE customer_id=ANY($1)',
        'DELETE FROM customer_whatsapp_links WHERE customer_id=ANY($1)',
        'DELETE FROM whatsapp_verification_sessions WHERE customer_id=ANY($1)'
      ]) { try { await pool.query(q, [ids]); } catch (e) {} }
      try { await pool.query('DELETE FROM customers WHERE id=ANY($1)', [ids]); } catch (e) {}
      return back(res, 'Deleted ' + ids.length + ' customer(s)');
    }
    back(res, 'Unknown action');
  });

  router.post('/customers/:id/block', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    try {
      const r = (await pool.query('UPDATE customers SET blocked=NOT COALESCE(blocked,false) WHERE id=$1 RETURNING blocked', [id])).rows[0];
      back(res, r && r.blocked ? 'Customer blocked — they can no longer sign in' : 'Customer unblocked');
    } catch (e) { back(res, 'Could not update the customer'); }
  });

  router.post('/customers/:id/delete', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    // keep the order history (null the link), clear auth-side records, then remove
    for (const q of [
      'UPDATE orders SET customer_id=NULL WHERE customer_id=$1',
      'DELETE FROM customer_tokens WHERE customer_id=$1',
      'DELETE FROM customer_carts WHERE customer_id=$1',
      'DELETE FROM customer_whatsapp_links WHERE customer_id=$1',
      'DELETE FROM whatsapp_verification_sessions WHERE customer_id=$1'
    ]) { try { await pool.query(q, [id]); } catch (e) {} }
    try { await pool.query('DELETE FROM customers WHERE id=$1', [id]); back(res, 'Customer deleted'); }
    catch (e) { back(res, 'Could not delete — the customer still has linked records'); }
  });

  return router;
};
