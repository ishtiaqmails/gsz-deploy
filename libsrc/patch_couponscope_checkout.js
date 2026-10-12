'use strict';
/* #80 — pass the ordered product_id(s) into coupon.validate() at all THREE sites so a
   product-scoped coupon is enforced everywhere: the live /api/coupon/validate preview
   (single + cart), the /checkout POST (single) and the /cart/place POST (cart).
   routes/checkout.js. Anchored, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_couponscope_checkout.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/checkout.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*couponScopeChk*/') >= 0) { console.log('skip (already): checkout coupon scope'); console.log('COUPONSCOPE-CHK OK'); process.exit(0); }

function rep(find, repl, label) {
  if (s.indexOf(find) < 0) throw new Error('ANCHOR MISS: ' + label);
  if (s.indexOf(find, s.indexOf(find) + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + label);
  s = s.replace(find, repl);
}

/* --- /api/coupon/validate: collect product ids per context --- */
rep("      let subtotalPkr = 0;",
    "      let subtotalPkr = 0, _pids = []; /*couponScopeChk*/", 'validate subtotal decl');
rep("        subtotalPkr = cl.total;",
    "        subtotalPkr = cl.total; _pids = (cl.lines || []).map(function (l) { return l.product_id; });", 'validate cart subtotal');
rep("        subtotalPkr = Number(plans[i].price_pkr || 0);",
    "        subtotalPkr = Number(plans[i].price_pkr || 0); _pids = [prow.id];", 'validate single subtotal');
rep("      const v = await coupon.validate(pool, code, subtotalPkr);",
    "      const v = await coupon.validate(pool, code, subtotalPkr, _pids);", 'validate call');

/* --- /checkout POST (single) --- */
rep("if (couponRaw) { const cv = await coupon.validate(pool, couponRaw, pkr); if (cv.ok) { discountPkr = cv.discountPkr; couponCode = cv.code; couponId = cv.couponId; } }",
    "if (couponRaw) { const cv = await coupon.validate(pool, couponRaw, pkr, [prow.id]); if (cv.ok) { discountPkr = cv.discountPkr; couponCode = cv.code; couponId = cv.couponId; } }", 'checkout POST validate');

/* --- /cart/place POST (cart) --- */
rep("if (couponRaw) { const cv = await coupon.validate(pool, couponRaw, total); if (cv.ok) { discountPkr = cv.discountPkr; couponCode = cv.code; couponId = cv.couponId; } }",
    "if (couponRaw) { const cv = await coupon.validate(pool, couponRaw, total, lines.map(function (l) { return l.product_id; })); if (cv.ok) { discountPkr = cv.discountPkr; couponCode = cv.code; couponId = cv.couponId; } }", 'cart POST validate');

fs.writeFileSync(file, s);
console.log('patched: coupon.validate receives product ids at all 3 sites');
console.log('COUPONSCOPE-CHK OK');
