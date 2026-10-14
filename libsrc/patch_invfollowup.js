'use strict';
/* Make the inventory/stock follow-up identical to the bot-order follow-up by routing it through
   the same deliveryMsg.compose().followup (sent via whatsapp.raw), instead of its own
   _iSec/_wSec + whatsapp.instructions template. Also prefer the plan's delivery_instructions
   (like the bot path). Span anchors (single-line start/end), CRLF-safe, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_invfollowup.js <ROOT>'); process.exit(1); }
const DV = path.join(ROOT, 'lib/deliver.js');

let s = fs.readFileSync(DV, 'utf8');
if (s.indexOf('_fup.followup') >= 0) { console.log('skip (already): inv-followup'); process.exit(0); }
const startStr = "const pr = (await pool.query('SELECT instructions, warranty FROM products WHERE id=$1', [o.product_id])).rows[0];";
const endStr = "idempotency_key: 'ord-' + o.id + '-instructions', delay_seconds: 4 });";
const i = s.indexOf(startStr); if (i < 0) throw new Error('SPAN START MISS: inv-followup');
const j = s.indexOf(endStr, i); if (j < 0) throw new Error('SPAN END MISS: inv-followup');

const repl =
  "const pr = (await pool.query('SELECT instructions, warranty FROM products WHERE id=$1', [o.product_id])).rows[0] || {};\n" +
  "        const _plw = (await pool.query('SELECT warranty, delivery_instructions FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0] || {};\n" +
  "        const _instr = ((_plw.delivery_instructions || '').trim()) || (pr.instructions || '');\n" +
  "        const _warr = ((_plw.warranty || '').trim()) || (pr.warranty || '');\n" +
  "        const _fup = deliveryMsg.compose(o, {}, { siteName: SITE, salesNumber: _sales, instructions: _instr, warranty: _warr });\n" +
  "        if (_fup && _fup.followup) await wanotify.enqueue({ customer_id: o.customer_id, order_id: o.id, destination_identity_id: link.whatsapp_identity_id, template_key: 'whatsapp.raw', vars: { body: _fup.followup }, idempotency_key: 'ord-' + o.id + '-instructions', delay_seconds: 4 });";

fs.writeFileSync(DV, s.slice(0, i) + repl + s.slice(j + endStr.length));
console.log('patched: inv-followup');
