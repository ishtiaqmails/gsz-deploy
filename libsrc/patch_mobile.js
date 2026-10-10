'use strict';
/* Mobile responsive polish for the home sections (source edit: appended to app.css).
   Fixes the desktop-grid-on-phone problems the owner flagged:
     - Shop by category: 2-col compact tiles with labels that fit (no "Entertainment" clip)
     - Reviews (.rev-grid): a swipeable horizontal carousel instead of a tall stacked list
     - Footer (.ft-top): 2 columns with the brand spanning, instead of one long column
   One <=560 media block, appended so it wins by source order. Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_mobile.js <app.css path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('gsz-mobile-fix') >= 0) { console.log('skip (already): mobile section fixes present'); console.log('MOBILE PATCH OK'); process.exit(0); }

const BLOCK = "\n\n/* gsz-mobile-fix — responsive home sections (phones) */\n" +
"@media(max-width:560px){\n" +
"  .catgrid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}\n" +
"  .cat-tile{padding:12px;gap:10px;min-width:0}\n" +
"  .cat-tile>span{min-width:0;overflow:hidden}\n" +
"  .cat-tile .cg{width:38px;height:38px;border-radius:11px}\n" +
"  .cat-tile .cg svg{width:19px;height:19px}\n" +
"  .cat-tile b{font-size:13px;overflow-wrap:anywhere}\n" +
"  .cat-tile .n{font-size:11px}\n" +
"  .rev-grid{display:flex;grid-template-columns:none;gap:12px;overflow-x:auto;overflow-y:hidden;scroll-snap-type:x mandatory;-webkit-overflow-scrolling:touch;padding-bottom:10px}\n" +
"  .rev-grid>*{flex:0 0 86%;scroll-snap-align:start;min-width:0}\n" +
"  .tp-card{padding:18px}\n" +
"  .ft-top{grid-template-columns:1fr 1fr;gap:22px 18px}\n" +
"  .ft-brand{grid-column:1/-1}\n" +
"}\n";

s = s.replace(/\s*$/, '') + BLOCK;
fs.writeFileSync(file, s);
console.log('patched: appended mobile section fixes (catgrid / reviews / footer)');
console.log('MOBILE PATCH OK');
