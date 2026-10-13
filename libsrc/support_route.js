'use strict';
/* Live Support Bot — Stage 3: the chat endpoint. POST /api/support/message runs the
   self-contained answer engine over the auto-indexed knowledge base and returns a grounded
   reply (+ product cards, suggestions, WhatsApp handoff). Scoped to the logged-in customer
   when there is one (req.session.customer) for the agentic actions wired in Stage 5.
   Deployed as routes/support.js. */
const express = require('express');
const kb = require('../lib/supportkb');
const bot = require('../lib/supportbot');
const sem = require('../lib/semclient');

function fmtDate(d) {
  try { return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); } catch (e) { return ''; }
}
function friendlyStatus(s) {
  switch (String(s || '').toLowerCase()) {
    case 'delivered': return 'Delivered ✅';
    case 'paid': case 'approved': case 'delivering': return 'Paid — delivering your order now ⏳';
    case 'verifying': return 'Verifying your payment ⏳';
    case 'pending': return 'Waiting for payment';
    case 'cancelled': return 'Cancelled';
    case 'failed': return 'Failed — please contact support';
    default: return (s ? (String(s).charAt(0).toUpperCase() + String(s).slice(1)) : 'Processing');
  }
}

module.exports = function (pool) {
  const router = express.Router();

  // keep the semantic sidecar populated OUT of the request path: once shortly after start,
  // then on a slow timer. Sig-gated, so it only re-embeds when content actually changed.
  // Requests never trigger a re-index (that caused a busy-embed spiral) — they only query /match.
  setTimeout(() => { sem.ensureIndexed(pool).catch(() => {}); }, 5000);
  setInterval(() => { sem.ensureIndexed(pool).catch(() => {}); }, 5 * 60 * 1000);

  // light per-session rate limit (chat abuse guard)
  const WINDOW = 60 * 1000, MAX = 30;
  function limited(req) {
    try {
      const s = req.session; if (!s) return false;
      const now = Date.now();
      if (!s._sbWin || now - s._sbWin > WINDOW) { s._sbWin = now; s._sbN = 0; }
      s._sbN = (s._sbN || 0) + 1;
      return s._sbN > MAX;
    } catch (e) { return false; }
  }

  router.post('/message', express.json(), async (req, res) => {
    try {
      const message = String((req.body && req.body.message) || '').slice(0, 500).trim();
      if (!message) return res.json({ ok: true, reply: 'Hi! Ask me about any product, price, plan, delivery, or your order.', products: [], suggestions: [] });
      if (limited(req)) return res.json({ ok: true, reply: 'You\'re sending messages very fast — give me a second please. 🙏', products: [], suggestions: [] });

      const k = await kb.get(pool);
      const customer = (req.session && req.session.customer) || null;

      let semMatch = null;                               // requests only QUERY the sidecar, never re-index it
      try { semMatch = await sem.match(message); } catch (e) {}

      // short conversation memory: last product discussed (per session, 20-min window)
      let lastProduct = null;
      try {
        const cx = req.session && req.session._sbCtx;
        if (cx && cx.id && (Date.now() - (cx.ts || 0) < 20 * 60 * 1000)) lastProduct = k.products.find(x => x.id === cx.id) || null;
      } catch (e) {}

      const a = bot.answer(k, message, { customer, lastProduct, sem: semMatch });

      // remember the product this turn settled on (for follow-ups); clear it when we showed a list
      try {
        if (req.session) {
          if (a.productId) req.session._sbCtx = { id: a.productId, ts: Date.now() };
          else if (a.clearCtx) delete req.session._sbCtx;
        }
      } catch (e) {}

      // guest-safe order tracking: look up status by order number (no credentials, no contact).
      if (a.needsAction === 'order_status' && a.orderNo) {
        try {
          const o = (await pool.query(
            "SELECT order_no, product_name, plan_label, status, created_at, delivered_at FROM orders WHERE upper(order_no)=upper($1) LIMIT 1",
            [a.orderNo])).rows[0];
          if (!o) {
            a.text = 'I couldn\'t find an order ' + a.orderNo + '. Please double-check the number (it looks like GSZ-1234), or tap WhatsApp and we\'ll help.';
            a.handoff = true;
          } else {
            a.text = a.orderNo + ' — ' + (o.product_name || 'Your order') + (o.plan_label ? (' (' + o.plan_label + ')') : '') +
              '\nStatus: ' + friendlyStatus(o.status) +
              (o.created_at ? ('\nPlaced: ' + fmtDate(o.created_at)) : '') +
              (o.delivered_at ? ('\nDelivered: ' + fmtDate(o.delivered_at)) : '');
            if (customer) a.actions = [{ label: 'View in My Orders', tool: 'purchases' }];
          }
        } catch (e) { a.text = 'I couldn\'t check that right now — please try again, or tap WhatsApp.'; a.handoff = true; }
      }

      res.json({
        ok: true,
        intent: a.intent,
        reply: a.text,
        products: a.products || [],
        suggestions: a.suggestions || [],
        actions: a.actions || [],
        handoff: !!a.handoff,
        needsAction: a.needsAction || null,
        orderNo: a.orderNo || null,
        signedIn: !!customer,
        wa: a.wa || null
      });
    } catch (e) {
      res.json({ ok: false, reply: 'Sorry, I hit a snag — please try again, or reach us on WhatsApp.' });
    }
  });

  // tiny info endpoint (what the KB currently holds) — handy for a health check
  router.get('/info', async (req, res) => {
    try { const k = await kb.get(pool); res.json({ ok: true, counts: k.counts, builtAt: k.builtAt, site: k.site.name }); }
    catch (e) { res.json({ ok: false }); }
  });

  return router;
};
