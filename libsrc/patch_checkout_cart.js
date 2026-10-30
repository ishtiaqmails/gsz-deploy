'use strict';
/* CHECKOUT_CART_v1 — Stage 3b: CART checkout USD = sum of each line's owner-set price_usd
   (live-rate fallback per line when blank), replacing the hardcoded total*0.0036. Display,
   selection, and recorded amount_usd all agree. Depends on Stage 3a's usdAmt() helper.
   Idempotent (done-marker-first); per-edit match count; split/join; throws on a miss. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const F = 'routes/checkout.js';

const edits = [
  // 1) buildCartLines plan query: select price_usd (compact, no-space form is unique to this query)
  { old: "id,label,price_pkr,source,bot_sku,bot_plan_key,bot_type,avail_from,avail_until,nf_portal_product_id FROM product_plans",
    neu: "id,label,price_pkr,price_usd,source,bot_sku,bot_plan_key,bot_type,avail_from,avail_until,nf_portal_product_id FROM product_plans",
    done: "price_pkr,price_usd,source", count: 1 },

  // 2) carry per-line price_usd on each cart line
  { old: "planIdx: idx, plan_id: plan.id, plan_label: plan.label, pricePkr: pkr, qty, lineTotal,",
    neu: "planIdx: idx, plan_id: plan.id, plan_label: plan.label, pricePkr: pkr, priceUsd: Number(plan.price_usd||0), qty, lineTotal,",
    done: "priceUsd: Number(plan.price_usd||0),", count: 1 },

  // 3) cartUsd(lines) helper — sum of per-line USD (price_usd*qty, else live fallback on lineTotal)
  { old: "  const reg = r => (REGIONS[r] ? r : 'PK');",
    neu: "  async function cartUsd(lines){ let s=0; for(const l of (lines||[])){ s += await usdAmt(Number(l.lineTotal||0), Number(l.priceUsd||0)*Number(l.qty||1)); } return +s.toFixed(2); }\n  const reg = r => (REGIONS[r] ? r : 'PK');",
    done: "async function cartUsd(lines)", count: 1 },

  // 4) every cart display USD -> the real cart USD (5 identical spots across cart/checkout + cart/place)
  { old: "total * REGIONS.US.rate", neu: "(await cartUsd(lines))",
    done: "fmt('$', (await cartUsd(lines)))", count: 5 },

  // 5) recorded cart amount_usd -> cart USD scaled by any coupon discount
  { old: "      const usdTotal = +(finalTotal * REGIONS.US.rate).toFixed(2);",
    neu: "      const usdTotal = +((await cartUsd(lines)) * (total > 0 ? finalTotal / total : 1)).toFixed(2);",
    done: "const usdTotal = +((await cartUsd(lines))", count: 1 },

  // 6) record per-item USD on the combined order (for receipts/records)
  { old: "pricePkr: l.pricePkr, qty: l.qty, source: l.source,",
    neu: "pricePkr: l.pricePkr, priceUsd: l.priceUsd||0, qty: l.qty, source: l.source,",
    done: "priceUsd: l.priceUsd||0, qty: l.qty,", count: 1 },
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
console.log('CHECKOUT_CART_v1 applied=' + applied + ' skipped=' + skipped);
