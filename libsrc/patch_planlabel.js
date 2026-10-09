'use strict';
/* Send planLabel on both submit-order payloads so the bot can render "Product — Plan"
   on the premium website cards. Reseller bot has no plans; website does. Safe if empty. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_planlabel.js <ROOT>'); process.exit(1); }
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
    name: 'single-planLabel',
    guard: 'planLabel: o.plan_label',
    find: "          productName: o.product_name || '',\n",
    replace: "          productName: o.product_name || '',\n          planLabel: o.plan_label || '',\n"
  },
  {
    name: 'cart-planLabel',
    guard: 'planLabel: (it.',
    find: "              productName: it.name || '',\n",
    replace: "              productName: it.name || '',\n              planLabel: (it.plan_label || it.planLabel || it.label || ''),\n"
  }
]);
console.log('PLANLABEL PATCH OK');
