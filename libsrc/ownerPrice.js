'use strict';
/* Owner price helper endpoint (Stage 4). Read-only. Secured by the same shared secret the bot
   already uses (wa_settings.wa_bot_webhook_secret / env WA_WEBHOOK_SECRET).
   GET /api/owner/price?secret=..&product=..&plan=..&country=US
   Reports, per matching plan: what a visitor in <country> sees by default, their local-currency
   option, and what each rail actually charges (Rs on bank, $ on Binance). Mirrors the live site:
   non-PK default = USD (no buffer); the buffer only shaves converted LOCAL currencies. */
const express = require('express');
module.exports = function (pool) {
  const router = express.Router();
  const pricing = require('../lib/gsz_pricing');

  async function secretOk(req) {
    try {
      const r = (await pool.query("SELECT value FROM wa_settings WHERE key='wa_bot_webhook_secret'")).rows[0];
      const want = (r && r.value) || process.env.WA_WEBHOOK_SECRET || '';
      const got = String((req.query && req.query.secret) || req.headers['x-webhook-secret'] || '');
      return !!want && got === want;
    } catch (e) { return false; }
  }

  router.get('/api/owner/price', async (req, res) => {
    if (!(await secretOk(req))) return res.status(401).json({ ok: false, error: 'unauthorized' });
    try {
      const q = String((req.query && req.query.product) || '').trim();
      const planQ = String((req.query && req.query.plan) || '').trim();
      const country = String((req.query && req.query.country) || 'US').trim().toUpperCase() || 'US';
      if (!q) return res.json({ ok: false, error: 'product required (e.g. ?product=netflix)' });

      const prow = (await pool.query(
        "SELECT id,name,slug FROM products WHERE slug=$1 OR name ILIKE $2 OR slug ILIKE $2 ORDER BY (slug=$1) DESC, id LIMIT 1",
        [q.toLowerCase(), '%' + q + '%'])).rows[0];
      if (!prow) return res.json({ ok: false, error: 'product not found: ' + q });

      let plans = (await pool.query(
        "SELECT label,price_pkr,price_usd FROM product_plans WHERE product_id=$1 ORDER BY sort,id", [prow.id])).rows;
      if (planQ) plans = plans.filter(p => String(p.label || '').toLowerCase().indexOf(planQ.toLowerCase()) >= 0);
      if (!plans.length) return res.json({ ok: false, error: 'no matching plan for "' + planQ + '" in ' + prow.name });

      let buf = 0;
      try { const b = (await pool.query("SELECT value FROM wa_settings WHERE key='price_buffer_pct'")).rows[0]; buf = b ? (parseFloat(b.value) || 0) : 0; } catch (e) {}

      const R = await pricing.rates(false);
      const usdPerPkr = (R && R.PKR) ? (1 / R.PKR) : 0;

      const out = [];
      for (const pl of plans) {
        const pkr = Number(pl.price_pkr || 0);
        const usdBase = Number(pl.price_usd || 0) > 0 ? Number(pl.price_usd) : +(pkr * usdPerPkr).toFixed(2);
        let defaultShown, localCurrency = null, localShown = null;
        if (country === 'PK') {
          defaultShown = 'Rs ' + Math.round(pkr).toLocaleString('en-US');
        } else {
          defaultShown = '$' + usdBase.toFixed(2); // non-PK default = USD, unbuffered (matches site)
          try {
            const q2 = await pricing.resolve({ price_pkr: pkr, price_usd: Number(pl.price_usd || 0) }, country, { bufferPct: buf });
            if (q2 && q2.currency && q2.currency !== 'USD') { localCurrency = q2.currency; localShown = q2.display; }
          } catch (e) {}
        }
        out.push({
          plan: pl.label,
          default_shown: defaultShown,
          local_currency: localCurrency,
          local_shown: localShown,
          pays_pkr: 'Rs ' + Math.round(pkr).toLocaleString('en-US'),
          pays_usd: '$' + usdBase.toFixed(2),
          price_usd_set: Number(pl.price_usd || 0) > 0
        });
      }
      res.json({ ok: true, product: prow.name, country, buffer_pct: buf, usd_rate: usdPerPkr ? +(1 / usdPerPkr).toFixed(2) : null, plans: out });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  return router;
};
