'use strict';
/* Add productName (our site's display name) to both submit-order payloads so the
   bot's delivery message shows OUR product name, not the reseller-bot catalog name.
   gsz-api accepts productName (preferred) and falls back to catalog name if absent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_productname.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

patch('routes/checkout.js', [
  {
    name: 'productName-single', guard: "productName: o.product_name",
    find: "          deliveryType: _dt,\n",
    replace: "          deliveryType: _dt,\n          productName: o.product_name || '',\n"
  },
  {
    name: 'productName-cart', guard: "productName: it.name",
    find: "              deliveryType: it.deliveryType || null,\n",
    replace: "              deliveryType: it.deliveryType || null,\n              productName: it.name || '',\n"
  }
]);
console.log('PRODUCTNAME PATCH OK');
