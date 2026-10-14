'use strict';
/* Bring routes/checkout.js notifyCustomerWa in line with the premium templates:
   the auto-delivery (at purchase) must pass the same vars as deliver.js —
   purchase date, plan line, sales number, and the Instructions+Warranty follow-up sections.
   Single-line / span anchors (CRLF + indentation robust). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_premsg_checkout.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/checkout.js');
let s = fs.readFileSync(file, 'utf8');

function once(name, guard, find, replace) {
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + replace + s.slice(i + find.length);
  console.log('patched: ' + name);
}
function span(name, guard, startStr, endStr, replace) {
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(startStr); if (i < 0) throw new Error('SPAN START MISS: ' + name);
  const j = s.indexOf(endStr, i); if (j < 0) throw new Error('SPAN END MISS: ' + name);
  s = s.slice(0, i) + replace + s.slice(j + endStr.length);
  console.log('patched: ' + name);
}

// 1) compute date / plan / sales number once a template is being sent
once('vars-compute', 'const _odate',
  "if (!tplKey) return;",
  "if (!tplKey) return;\n    const _odate = (function(){ try { return new Date(o.created_at || Date.now()).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }); } catch (e) { return ''; } })();\n    const _pline = o.plan_label ? ('\\u23f3 Plan  \\u00b7  ' + o.plan_label) : '';\n    const _nums = await pool.query(\"SELECT key,value FROM wa_settings WHERE key IN ('wa_support_number','wa_sales_number')\").then(function(r){ var m={}; (r.rows||[]).forEach(function(x){ m[x.key]=x.value; }); return m; }).catch(function(){ return {}; });\n    const _sales = String(_nums.wa_sales_number || _nums.wa_support_number || '').replace(/[^0-9]/g, '');");

// 2) pass them into the credentials/lifecycle message
once('credentials-vars', 'order_date:_odate',
  "secure_link:secLink, credentials:o.delivered_credentials||'' }",
  "secure_link:secLink, credentials:o.delivered_credentials||'', order_date:_odate, plan_line:_pline, sales_number:_sales }");

// 3) follow-up carries Instructions + Warranty (only when either exists)
span('instr-warranty', 'instructions_section:',
  "const _pr = (await pool.query('SELECT instructions FROM products",
  "idempotency_key:'ord-'+o.id+'-instructions', delay_seconds:4 });",
  "const _pr = (await pool.query('SELECT instructions, warranty FROM products WHERE id=$1', [o.product_id])).rows[0] || {};\n        const _plw = (await pool.query('SELECT warranty FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0];\n        const _instr = (_pr.instructions) ? String(_pr.instructions).trim() : '';\n        const _warr = ((_plw && _plw.warranty) ? String(_plw.warranty).trim() : (_pr.warranty ? String(_pr.warranty).trim() : ''));\n        const _iSec = _instr ? ('*How to use*\\n' + _instr + '\\n\\n') : '';\n        const _wSec = _warr ? ('\\ud83d\\udee1\\ufe0f *Warranty*\\n' + _warr + '\\n\\n') : '';\n        if (_iSec || _wSec) await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:link.whatsapp_identity_id, template_key:'whatsapp.instructions', vars:{ site_name:'Galaxy Subz \\u00d7 Zayron', product_name:o.product_name||'', instructions_section:_iSec, warranty_section:_wSec, sales_number:_sales }, idempotency_key:'ord-'+o.id+'-instructions', delay_seconds:4 });");

fs.writeFileSync(file, s);
console.log('PREMSG-CHECKOUT PATCH OK');
