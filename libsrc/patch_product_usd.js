'use strict';
/* PRODUCT_USD_v1 — Stage 3c: the public product page carries price_usd so a SET dollar price
   shows on the product pills exactly as it's charged at checkout (blank still converts PKR).
   2 edits in routes/products.js. Idempotent (done-marker-first); split/join; throws on a miss. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const F = 'routes/products.js';

const edits = [
  // 1) plan query: select price_usd
  { old: "price_pkr, old_pkr, source, bot_sku, bot_type, avail_from",
    neu: "price_pkr, old_pkr, price_usd, source, bot_sku, bot_type, avail_from",
    done: "price_pkr, old_pkr, price_usd, source, bot_sku, bot_type", count: 1 },
  // 2) plan map: carry price_usd (pills read pl.price_usd)
  { old: "price: Number(r.price_pkr || 0), old: Number(r.old_pkr || 0),",
    neu: "price: Number(r.price_pkr || 0), price_usd: Number(r.price_usd || 0), old: Number(r.old_pkr || 0),",
    done: "price_usd: Number(r.price_usd || 0),", count: 1 },
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
console.log('PRODUCT_USD_v1 applied=' + applied + ' skipped=' + skipped);
