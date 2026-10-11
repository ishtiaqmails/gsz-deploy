'use strict';
/* Make the customer's order self-aware of the plan's delivery_instructions + product_note
   (set on the product page). /account/tools/orders already LEFT JOINs product_plans (pp);
   just select the two columns and return them. Idempotent; hard-fails if an anchor is missing. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_orderinfo.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');
const miss = [];
function sub(find, repl, name, already) {
  if (s.indexOf(already) >= 0) { console.log(name + ': already (skip)'); return; }
  if (s.indexOf(find) >= 0) { s = s.split(find).join(repl); console.log(name + ': ok'); }
  else miss.push(name);
}
sub("bp.warranty_days AS bot_warranty_days FROM orders o",
    "bp.warranty_days AS bot_warranty_days, pp.delivery_instructions, pp.product_note FROM orders o",
    "orders select", "pp.delivery_instructions, pp.product_note FROM orders o");
sub("credentials: done?(o.delivered_credentials||''):'',",
    "credentials: done?(o.delivered_credentials||''):'', delivery_instructions: done?(o.delivery_instructions||''):'', product_note:(o.product_note||''),",
    "orders response", "delivery_instructions: done?(o.delivery_instructions||''):''");
if (miss.length) { console.error('PATCH FAILED — anchors not found: ' + miss.join(', ')); process.exit(2); }
fs.writeFileSync(file, s);
console.log('ORDERINFO OK');
