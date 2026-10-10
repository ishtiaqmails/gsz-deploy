'use strict';
/* Admin product editor: add a "Renewable" checkbox (just before the Hide checkbox).
   Default checked (new products + existing default true). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodedit.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/admin/product_edit.ejs');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('name="renewable"') >= 0) { console.log('skip (already): renewable checkbox present'); console.log('PRODEDIT PATCH OK'); process.exit(0); }

const anchor = '<label style="display:flex;align-items:center;gap:8px;font-size:14px;font-weight:600;margin-top:4px"><input type="checkbox" name="hidden"';
const add = '<label style="display:flex;align-items:center;gap:8px;font-size:14px;font-weight:600;margin-top:4px"><input type="checkbox" name="renewable" style="width:auto;margin:0" <%= (!prod || prod.renewable)?\'checked\':\'\' %>> Renewable — show this product in the customer “Renew” tool</label>\n    ';
if (s.indexOf(anchor) < 0) throw new Error('ANCHOR MISS: hidden checkbox not found in product_edit.ejs');
s = s.replace(anchor, add + anchor);
fs.writeFileSync(file, s);
console.log('patched: added Renewable checkbox to product editor');
console.log('PRODEDIT PATCH OK');
