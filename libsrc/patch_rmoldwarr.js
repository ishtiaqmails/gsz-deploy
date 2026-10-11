'use strict';
/* Remove the OLD product-page warranty (#pWarranty + its data-warranty pill attr + its JS),
   keeping the NEW green warranty shield (#planWarr / data-warr). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_rmoldwarr.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/product.ejs');
let s = fs.readFileSync(file, 'utf8'); let n = 0;

// 1) old data-warranty attribute on the pill
const A = " data-warranty=\"<%= pl.warranty || '' %>\"";
if (s.indexOf(A) >= 0) { s = s.split(A).join(''); n++; console.log('old data-warranty attr: removed'); } else { console.log('old data-warranty attr: not found'); }

// 2) old #pWarranty div
const B = "\n      <div id=\"pWarranty\" style=\"display:none;margin:0 0 14px;font-size:13.5px;font-weight:600;color:var(--ink-soft)\"></div>";
if (s.indexOf(B) >= 0) { s = s.split(B).join(''); n++; console.log('old #pWarranty div: removed'); } else { console.log('old #pWarranty div: not found'); }

// 3) old JS line that fills #pWarranty (regex skips the emoji literal)
const RE = /\n[ ]*var _w=sel\?\(sel\.getAttribute\('data-warranty'\)\|\|''\):''; var _we=document\.getElementById\('pWarranty'\);[^\n]*/;
if (RE.test(s)) { s = s.replace(RE, ''); n++; console.log('old pWarranty JS: removed'); } else { console.log('old pWarranty JS: not found'); }

if (n) fs.writeFileSync(file, s);
console.log('RMOLDWARR OK (' + n + ' removed)');
