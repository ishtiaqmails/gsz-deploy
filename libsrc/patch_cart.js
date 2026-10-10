'use strict';
/* Cart drawer on phones (source edit: appended to cart.css). The drawer is width:min(420px,92vw),
   which on a 375px screen is 345px — an awkward near-full sliver. Make it a clean full-width cart
   on phones, and pad the bottom so its content clears the app bottom-nav. Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_cart.js <cart.css path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('gsz-cart-mobile') >= 0) { console.log('skip (already): cart mobile fix present'); console.log('CART PATCH OK'); process.exit(0); }

const BLOCK = "\n\n/* gsz-cart-mobile — full-width cart on phones, clear the app bar */\n" +
"@media(max-width:560px){\n" +
"  .gszcart-drawer{width:100vw;max-width:100vw;border-left:0}\n" +
"  .gszcart-body{padding-bottom:calc(84px + env(safe-area-inset-bottom))}\n" +
"}\n";

s = s.replace(/\s*$/, '') + BLOCK;
fs.writeFileSync(file, s);
console.log('patched: appended cart mobile fix (full-width + bottom clearance)');
console.log('CART PATCH OK');
