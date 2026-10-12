'use strict';
/* #81 — 100%-off coupon skips checkout (single-product /checkout). When a valid coupon
   zeroes the total, no payment method or proof is required: the order is created already
   'paid' and fulfilled directly via fulfill() (the same delivery path a verified-paid
   order uses), bypassing payment verification. Also exposes `free` on /api/coupon/validate.
   routes/checkout.js. Anchored, idempotent. Requires #80 (scope) already applied. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_freeorder.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/checkout.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*freeOrder*/') >= 0) { console.log('skip (already): free order'); console.log('FREEORDER OK'); process.exit(0); }

function rep(find, repl, label, mustBeUnique) {
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + label);
  if (mustBeUnique && s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + label);
  s = s.slice(0, i) + repl + s.slice(i + find.length);
}

/* A) expose free flag on the live validator */
rep("        ok: true, code: v.code, label: v.label, discountPkr: v.discountPkr,",
    "        ok: true, code: v.code, label: v.label, discountPkr: v.discountPkr, free: !!v.free,",
    'validate response free', true);

/* B) reorder: compute coupon + finalPkr + isFree BEFORE the payment-method requirement */
rep(
  "      const chosen = methods.find(x => x.key === method_key);\n" +
  "      if (!chosen) return fail('Please choose a payment method.');\n" +
  "\n" +
  "      let discountPkr = 0, couponCode = null, couponId = null;\n" +
  "      const couponRaw = String(b.coupon || '').trim();\n" +
  "      if (couponRaw) { const cv = await coupon.validate(pool, couponRaw, pkr, [prow.id]); if (cv.ok) { discountPkr = cv.discountPkr; couponCode = cv.code; couponId = cv.couponId; } }\n" +
  "      const finalPkr = Math.max(0, pkr - discountPkr);",
  "      let discountPkr = 0, couponCode = null, couponId = null;\n" +
  "      const couponRaw = String(b.coupon || '').trim();\n" +
  "      if (couponRaw) { const cv = await coupon.validate(pool, couponRaw, pkr, [prow.id]); if (cv.ok) { discountPkr = cv.discountPkr; couponCode = cv.code; couponId = cv.couponId; } }\n" +
  "      const finalPkr = Math.max(0, pkr - discountPkr);\n" +
  "      const isFree = (finalPkr <= 0 && !!couponId); /*freeOrder*/\n" +
  "      const chosen = isFree ? { key: 'free', name: 'Free (coupon)', botAcct: false } : methods.find(x => x.key === method_key);\n" +
  "      if (!chosen) return fail('Please choose a payment method.');",
  'single chosen/coupon reorder', true);

/* C) proof not required for a free order */
rep("      if (!req.file) return fail('Please upload your payment screenshot or receipt — proof of payment is required.');",
    "      if (!isFree && !req.file) return fail('Please upload your payment screenshot or receipt — proof of payment is required.');",
    'single proof check', true);

/* D) free order is created already paid */
rep("      const startStatus = botPay ? 'verifying' : 'pending';\n\n      const ins = await pool.query(",
    "      const startStatus = isFree ? 'paid' : (botPay ? 'verifying' : 'pending');\n\n      const ins = await pool.query(",
    'single start status', true);

/* E) free order fulfils directly (no payment to verify) */
rep("      if (couponId) { /* coupon:single */ try { await pool.query('UPDATE orders SET coupon_code=$1, discount_pkr=$2 WHERE id=$3', [couponCode, discountPkr, id]); await pool.query('UPDATE coupons SET used_count=COALESCE(used_count,0)+1 WHERE id=$1', [couponId]); } catch (e) {} }\n\n      if (botPay) reverifyOrder(id).catch(() => {});",
    "      if (couponId) { /* coupon:single */ try { await pool.query('UPDATE orders SET coupon_code=$1, discount_pkr=$2 WHERE id=$3', [couponCode, discountPkr, id]); await pool.query('UPDATE coupons SET used_count=COALESCE(used_count,0)+1 WHERE id=$1', [couponId]); } catch (e) {} }\n\n      if (isFree) { fulfill(id).catch(() => {}); } else if (botPay) reverifyOrder(id).catch(() => {});",
    'single fulfil trigger', true);

fs.writeFileSync(file, s);
console.log('patched: single checkout supports free (100%-off) orders');
console.log('FREEORDER OK');
