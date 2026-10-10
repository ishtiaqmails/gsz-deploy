'use strict';
/* Home page: remove the "Try IPTV free before you buy" FREE TRIAL CTA band and put the
   Customer Tools include (Quick Access band + pop-up) in its place. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_home.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/home.ejs');
let s = fs.readFileSync(file, 'utf8');
const INC = "<%- include('partials/customer_tools') %>";

if (s.indexOf("partials/customer_tools") >= 0) {
  console.log('skip (already): customer_tools include present');
} else {
  const start = s.indexOf('<!-- FREE TRIAL CTA -->');
  if (start < 0) throw new Error('ANCHOR MISS: <!-- FREE TRIAL CTA --> not found');
  const endTok = '</section>';
  const endIdx = s.indexOf(endTok, start);
  if (endIdx < 0) throw new Error('ANCHOR MISS: closing </section> after FREE TRIAL CTA not found');
  const end = endIdx + endTok.length;
  s = s.slice(0, start) + INC + s.slice(end);
  fs.writeFileSync(file, s);
  console.log('patched: views/home.ejs :: replaced FREE TRIAL CTA band with customer_tools include');
}
console.log('HOME PATCH OK');
