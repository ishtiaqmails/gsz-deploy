'use strict';
/* Product page "You may also like" section: the shared .pgrid is a wrap grid, so 8 similar
   products orphan a 2-card second row with a big empty gap. Scope ONLY the product page's
   similar section (.pdp-sec .pgrid) to a single-row horizontal scroll rail — no orphan rows at
   any count, matches the "View all →" affordance. Higher-specificity override, no !important.
   The shared grid used on home/category pages is untouched. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_pdprail.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/product.ejs');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('pdp similar rail') >= 0) { console.log('pdprail: present (skip)'); }
else {
  const ANCH = "<%- include('partials/store_top') %>";
  const CSS =
    "\n<style>/* pdp similar rail — single-row horizontal scroll, no orphan rows */\n" +
    ".pdp-sec .pgrid{display:flex;flex-wrap:nowrap;grid-template-columns:none;gap:16px;overflow-x:auto;overflow-y:hidden;scroll-snap-type:x proximity;padding:4px 2px 14px;-webkit-overflow-scrolling:touch;scrollbar-width:thin}\n" +
    ".pdp-sec .pgrid>*{flex:0 0 232px;scroll-snap-align:start}\n" +
    ".pdp-sec .pgrid::-webkit-scrollbar{height:8px}\n" +
    ".pdp-sec .pgrid::-webkit-scrollbar-thumb{background:rgba(255,255,255,.16);border-radius:999px}\n" +
    ".pdp-sec .pgrid::-webkit-scrollbar-track{background:transparent}\n" +
    "@media(max-width:860px){.pdp-sec .pgrid>*{flex:0 0 76%}}\n</style>";
  if (s.indexOf(ANCH) >= 0) { s = s.replace(ANCH, ANCH + CSS); fs.writeFileSync(file, s); console.log('pdprail: rail css added'); }
  else { console.log('pdprail: anchor missing (skip)'); }
}
console.log('PDPRAIL OK');
