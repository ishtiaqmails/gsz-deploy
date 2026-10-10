'use strict';
/* Cart on phones (source edit: appended to cart.css). Not full-screen, premium & clear: a bottom
   sheet that slides up, rounded top, leaves the top of the screen showing the page behind, and sits
   above the app bar so nothing overlaps. Re-appliable: replaces its own prior block (brace-matched). */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_cart.js <cart.css path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

const BLOCK =
"/* gsz-cart-mobile — premium bottom-sheet cart on phones */\n" +
"@media(max-width:560px){\n" +
"  .gszcart-scrim{z-index:119;background:rgba(3,5,12,.66)}\n" +
"  .gszcart-drawer{top:auto;bottom:0;left:0;right:0;width:100%;max-width:100%;height:auto;max-height:86vh;border-left:0;border-top:1px solid rgba(255,255,255,.1);border-radius:22px 22px 0 0;transform:translateY(100%);z-index:120;box-shadow:0 -24px 60px -20px rgba(0,0,0,.8)}\n" +
"  .gszcart-drawer.on{transform:translateY(0)}\n" +
"  .gszcart-body{padding-bottom:calc(18px + env(safe-area-inset-bottom))}\n" +
"}\n";

// remove any previous gsz-cart-mobile block (comment + brace-matched @media{...})
let idx;
while ((idx = s.indexOf('/* gsz-cart-mobile')) >= 0) {
  const braceStart = s.indexOf('{', idx);
  if (braceStart < 0) { s = s.slice(0, idx); break; }
  let depth = 0, end = -1;
  for (let i = braceStart; i < s.length; i++) { if (s[i] === '{') depth++; else if (s[i] === '}') { depth--; if (depth === 0) { end = i; break; } } }
  if (end < 0) { s = s.slice(0, idx); break; }
  s = s.slice(0, idx) + s.slice(end + 1);
}

s = s.replace(/\s+$/, '') + '\n\n' + BLOCK;
fs.writeFileSync(file, s);
console.log('patched: cart bottom-sheet on phones (premium, not full-screen)');
console.log('CART PATCH OK');
