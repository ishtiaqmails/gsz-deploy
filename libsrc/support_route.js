'use strict';
/* Live Support Bot — Stage 3: the chat endpoint. POST /api/support/message runs the
   self-contained answer engine over the auto-indexed knowledge base and returns a grounded
   reply (+ product cards, suggestions, WhatsApp handoff). Scoped to the logged-in customer
   when there is one (req.session.customer) for the agentic actions wired in Stage 5.
   Deployed as routes/support.js. */
const express = require('express');
const kb = require('../lib/supportkb');
const bot = require('../lib/supportbot');

module.exports = function (pool) {
  const router = express.Router();

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
      const a = bot.answer(k, message, { customer });

      res.json({
        ok: true,
        intent: a.intent,
        reply: a.text,
        products: a.products || [],
        suggestions: a.suggestions || [],
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
