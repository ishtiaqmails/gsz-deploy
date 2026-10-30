'use strict';
/* CHECKOUT_USD_v1 — Stage 3a: SINGLE-PRODUCT checkout charges the owner-set price_usd on the
   USD/Binance rail (live-rate fallback via the Stage-1 engine when a plan's USD is blank),
   instead of the hardcoded pkr*0.0036. Display, charge, and recorded amount_usd all agree.
   Cart paths are Stage 3b (untouched here). Idempotent (done-marker-first); per-edit match
   count; split/join (immune to $ patterns); throws on a miss so the deploy step restores. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const F = 'routes/checkout.js';

const REGIONS_LINE = "  const REGIONS = { PK: { cur: 'Rs', rate: 1 }, US: { cur: '$', rate: 0.0036 }, GB: { cur: '£', rate: 0.0028 }, AE: { cur: 'AED', rate: 0.013 } };";
const HELPER = "\n  const pricing = require('../lib/gsz_pricing');\n" +
  "  async function usdAmt(pkr, priceUsd){ priceUsd = Number(priceUsd || 0); if (priceUsd > 0) return +priceUsd.toFixed(2); try { const R = await pricing.rates(false); const upp = (R && R.PKR) ? (1 / R.PKR) : REGIONS.US.rate; return +((Number(pkr || 0)) * upp).toFixed(2); } catch (e) { return +((Number(pkr || 0)) * REGIONS.US.rate).toFixed(2); } }";

const edits = [
  // 1) helper + engine require, right after REGIONS
  { old: REGIONS_LINE, neu: REGIONS_LINE + HELPER, done: "async function usdAmt(pkr, priceUsd)", count: 1 },

  // 2) GET plan query: select price_usd
  { old: "price_pkr, old_pkr, source,", neu: "price_pkr, old_pkr, price_usd, source,", done: "old_pkr, price_usd, source,", count: 1 },

  // 3) POST plan query: select price_usd
  { old: "price_pkr, source, bot_sku, bot_plan_key, bot_type, avail_from, avail_until, nf_portal_product_id FROM product_plans",
    neu: "price_pkr, price_usd, source, bot_sku, bot_plan_key, bot_type, avail_from, avail_until, nf_portal_product_id FROM product_plans",
    done: "price_pkr, price_usd, source, bot_sku, bot_plan_key", count: 1 },

  // 4) single-product USD (feeds display methods + selection) — identical line in GET and POST, both have plan+pkr
  { old: "      const usd = pkr * REGIONS.US.rate;", neu: "      const usd = await usdAmt(pkr, plan.price_usd);",
    done: "const usd = await usdAmt(pkr, plan.price_usd);", count: 2 },

  // 5) recorded amount_usd on the single-product order (scales price_usd by any coupon discount)
  { old: "      const usdv = +(finalPkr * REGIONS.US.rate).toFixed(2);",
    neu: "      const usdv = await usdAmt(finalPkr, (pkr > 0 ? (Number(plan.price_usd || 0) * finalPkr / pkr) : Number(plan.price_usd || 0)));",
    done: "const usdv = await usdAmt(", count: 1 },

  // 6) bot-account (Binance) branch: show the passed USD amount, not the hardcoded usdtAmount(pkr)
  { old: "              pay: isUsd ? (String(a.currency || 'USDT') + ' ' + usdtAmount(pkr)) : fmt('Rs', pkr),",
    neu: "              pay: isUsd ? (String(a.currency || 'USDT') + ' ' + (+Number(usd || 0).toFixed(2))) : fmt('Rs', pkr),",
    done: "' ' + (+Number(usd || 0).toFixed(2))", count: 1 },

  // 7) coupon endpoint: live-rate USD instead of hardcoded (price_usd stays the charge via edit 5)
  { old: "      const usd = finalPkr * REGIONS.US.rate;", neu: "      const usd = await usdAmt(finalPkr, 0);",
    done: "const usd = await usdAmt(finalPkr, 0);", count: 1 },

  // 8) pay-methods AJAX tool: live-rate USD instead of hardcoded
  { old: "      const region = reg(req.query.region); const pkr = Number(req.query.amount||0)||0; const usd = pkr * REGIONS.US.rate;",
    neu: "      const region = reg(req.query.region); const pkr = Number(req.query.amount||0)||0; const usd = await usdAmt(pkr, 0);",
    done: "const pkr = Number(req.query.amount||0)||0; const usd = await usdAmt(", count: 1 },
];

let s = fs.readFileSync(path.join(ROOT, F), 'utf8');
let applied = 0, skipped = 0;
for (const e of edits) {
  if (s.indexOf(e.done) >= 0) { skipped++; continue; }
  const n = s.split(e.old).length - 1;
  const want = e.count || 1;
  if (n === 0) throw new Error('ANCHOR MISSING in ' + F + ': ' + e.old.slice(0, 55));
  if (n !== want) throw new Error('anchor count ' + n + ' (want ' + want + ') for: ' + e.old.slice(0, 45));
  s = s.split(e.old).join(e.neu); applied += n;
}
fs.writeFileSync(path.join(ROOT, F), s);
console.log('CHECKOUT_USD_v1 applied=' + applied + ' skipped=' + skipped);
