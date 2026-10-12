'use strict';
/* #80 — make lib/coupon.js validate() product-scope-aware.
   New optional 4th arg productIds (the product_id, or array of product_ids, in the order).
   If the coupon has rows in coupon_products, EVERY ordered product must be in that set,
   otherwise the code is rejected. No rows = applies to all products (unchanged behaviour).
   Also returns `free` (true when the discount zeroes a non-zero subtotal) for the #81 flow.
   Three small anchored edits. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_couponlib.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'lib/coupon.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*couponScope*/') >= 0) { console.log('skip (already): coupon scope'); console.log('COUPONLIB OK'); process.exit(0); }

/* 1) signature: add productIds */
const SIG = 'async function validate(pool, code, subtotalPkr) {';
if (s.indexOf(SIG) < 0) throw new Error('ANCHOR MISS: validate signature');
s = s.replace(SIG, 'async function validate(pool, code, subtotalPkr, productIds) { /*couponScope*/');

/* 2) scope check: insert right after the usage-limit guard */
const AFTER = "  if (c.usage_limit != null && Number(c.used_count) >= Number(c.usage_limit)) return { ok: false, reason: 'That code has reached its limit.' };";
if (s.indexOf(AFTER) < 0) throw new Error('ANCHOR MISS: usage-limit guard');
const SCOPE =
  "\n  let _scope = [];" +
  "\n  try { _scope = (await pool.query('SELECT product_id FROM coupon_products WHERE coupon_id=$1', [c.id])).rows.map(function (r) { return Number(r.product_id); }); } catch (e) { _scope = []; }" +
  "\n  if (_scope.length) {" +
  "\n    const _ids = (Array.isArray(productIds) ? productIds : (productIds != null ? [productIds] : [])).map(Number).filter(function (x) { return x; });" +
  "\n    if (!_ids.length || !_ids.every(function (pid) { return _scope.indexOf(pid) >= 0; })) return { ok: false, reason: \"This code isn't valid for the selected product.\" };" +
  "\n  }";
s = s.replace(AFTER, AFTER + SCOPE);

/* 3) final return: add free flag */
const RET = "  return { ok: true, discountPkr: Math.round(disc), code: c.code, label: label, couponId: c.id };";
if (s.indexOf(RET) < 0) throw new Error('ANCHOR MISS: success return');
s = s.replace(RET, "  return { ok: true, discountPkr: Math.round(disc), code: c.code, label: label, couponId: c.id, free: (sub > 0 && Math.round(disc) >= sub) };");

fs.writeFileSync(file, s);
console.log('patched: coupon.validate is product-scope-aware (+free flag)');
console.log('COUPONLIB OK');
