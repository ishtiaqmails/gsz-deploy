'use strict';
/* Premium WhatsApp delivery (lib/deliver.js, customerWa):
   - main credentials message gets order_date + plan_line vars (purchase date, plan).
   - the follow-up message carries Instructions AND Warranty (product + plan), sent only when
     either exists. Templates themselves are updated by stepPreMsg.sh.
   Anchors are single-line substrings (robust to indentation / CRLF). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_premsg.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'lib/deliver.js');
let s = fs.readFileSync(file, 'utf8');

function once(name, guard, find, replace) {
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + replace + s.slice(i + find.length);
  console.log('patched: ' + name);
}
// replace an inclusive span between two single-line anchors
function span(name, guard, startStr, endStr, replace) {
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(startStr); if (i < 0) throw new Error('SPAN START MISS: ' + name);
  const j = s.indexOf(endStr, i); if (j < 0) throw new Error('SPAN END MISS: ' + name);
  const end = j + endStr.length;
  s = s.slice(0, i) + replace + s.slice(end);
  console.log('patched: ' + name);
}

// 1) compute purchase date + plan line
once('date-plan-vars', 'const _odate',
  "let tplKey, secLink = '';",
  "let tplKey, secLink = '';\n      const _odate = (function(){ try { return new Date(o.created_at || Date.now()).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }); } catch (e) { return ''; } })();\n      const _pline = o.plan_label ? ('\\u23f3 Plan  \\u00b7  ' + o.plan_label) : '';\n      const _nums = await pool.query(\"SELECT key,value FROM wa_settings WHERE key IN ('wa_support_number','wa_sales_number')\").then(function(r){ var m={}; (r.rows||[]).forEach(function(x){ m[x.key]=x.value; }); return m; }).catch(function(){ return {}; });\n      const _support = String(_nums.wa_support_number || _nums.wa_sales_number || '').replace(/[^0-9]/g, '');\n      const _sales = String(_nums.wa_sales_number || _nums.wa_support_number || '').replace(/[^0-9]/g, '');");

// 2) pass them into the credentials message
once('credentials-vars', 'order_date: _odate',
  "credentials: o.delivered_credentials || '' }",
  "credentials: o.delivered_credentials || '', order_date: _odate, plan_line: _pline, support_number: _support, sales_number: _sales }");

// 3) fetch warranty alongside instructions
once('pr-warranty', 'instructions, warranty FROM products',
  "SELECT instructions FROM products WHERE id=$1",
  "SELECT instructions, warranty FROM products WHERE id=$1");

// 4) follow-up carries Instructions + Warranty, only when either exists
span('instr-warranty-block', 'warranty_section: _wSec, sales_number',
  "const instr = (pr && pr.instructions)",
  "idempotency_key: 'ord-' + o.id + '-instructions', delay_seconds: 4 });",
  "const instr = (pr && pr.instructions) ? String(pr.instructions).trim() : '';\n" +
  "        const _plw = (await pool.query('SELECT warranty FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0];\n" +
  "        const _warr = ((_plw && _plw.warranty) ? String(_plw.warranty).trim() : ((pr && pr.warranty) ? String(pr.warranty).trim() : ''));\n" +
  "        const _iSec = instr ? ('*How to use*\\n' + instr + '\\n\\n') : '';\n" +
  "        const _wSec = _warr ? ('\\ud83d\\udee1\\ufe0f *Warranty*\\n' + _warr + '\\n\\n') : '';\n" +
  "        if (_iSec || _wSec) await wanotify.enqueue({ customer_id: o.customer_id, order_id: o.id, destination_identity_id: link.whatsapp_identity_id, template_key: 'whatsapp.instructions', vars: { site_name: SITE, product_name: o.product_name || '', instructions_section: _iSec, warranty_section: _wSec, sales_number: _sales }, idempotency_key: 'ord-' + o.id + '-instructions', delay_seconds: 4 });");

fs.writeFileSync(file, s);
console.log('PREMSG PATCH OK');
