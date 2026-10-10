'use strict';
/* Mobile responsive polish for the home sections (source edit: appended to app.css).
     - Shop by category: 2-col compact tiles with labels that fit (no "Entertainment" clip)
     - Reviews: rev-grid is [summary card, .rev-cards]; stack them, then make .rev-cards a swipeable
       horizontal carousel of the individual review cards (not a tall stack)
     - Footer (.ft-top): 2 columns with the brand spanning
   Re-appliable: removes its own previous block (brace-matched) before appending the current one. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_mobile.js <app.css path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

const BLOCK =
"/* gsz-mobile-fix — responsive home sections (phones) */\n" +
"@media(max-width:560px){\n" +
"  .catgrid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}\n" +
"  .cat-tile{padding:12px;gap:10px;min-width:0}\n" +
"  .cat-tile>span{min-width:0;overflow:hidden}\n" +
"  .cat-tile .cg{width:38px;height:38px;border-radius:11px}\n" +
"  .cat-tile .cg svg{width:19px;height:19px}\n" +
"  .cat-tile b{font-size:13px;overflow-wrap:anywhere}\n" +
"  .cat-tile .n{font-size:11px}\n" +
"  .rev-grid{display:block}\n" +
"  .rev-cards{display:flex;gap:12px;overflow-x:auto;overflow-y:hidden;scroll-snap-type:x mandatory;-webkit-overflow-scrolling:touch;padding-bottom:10px;margin-top:14px}\n" +
"  .rev-cards>*{flex:0 0 82%;scroll-snap-align:start;min-width:0}\n" +
"  .tp-card{padding:18px}\n" +
"  .ft-top{grid-template-columns:1fr 1fr;gap:22px 18px}\n" +
"  .ft-brand{grid-column:1/-1}\n" +
"}\n";

// remove any previous gsz-mobile-fix block (comment + its brace-matched @media{...})
let idx;
while ((idx = s.indexOf('/* gsz-mobile-fix')) >= 0) {
  const braceStart = s.indexOf('{', idx);
  if (braceStart < 0) { s = s.slice(0, idx); break; }
  let depth = 0, end = -1;
  for (let i = braceStart; i < s.length; i++) { if (s[i] === '{') depth++; else if (s[i] === '}') { depth--; if (depth === 0) { end = i; break; } } }
  if (end < 0) { s = s.slice(0, idx); break; }
  s = s.slice(0, idx) + s.slice(end + 1);
}

s = s.replace(/\s+$/, '') + '\n\n' + BLOCK;
fs.writeFileSync(file, s);
console.log('patched: mobile section fixes applied (catgrid / reviews carousel / footer)');
console.log('MOBILE PATCH OK');
