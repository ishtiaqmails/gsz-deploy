'use strict';
/* Wire the premium composer into bot-order delivery, in BOTH notify paths:
     routes/checkout.js  (auto delivery)   and   lib/deliver.js (manual admin deliver).
   On a delivered bot order: fetch the bot `fields`, compose the premium main + follow-up
   (data from bot; How-to-Use/Warranty from the website admin), send via the `whatsapp.raw`
   passthrough, and return. If fields are missing / bot unreachable, fall through to the
   existing generic path (sends the raw text) — never a broken message.
   Single-line anchors (CRLF/indent robust). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_premsg_bot.js <ROOT>'); process.exit(1); }

function edit(rel, ops) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const o of ops) {
    if (s.indexOf(o.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + o.name); continue; }
    const i = s.indexOf(o.find);
    if (i < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + o.name);
    if (s.indexOf(o.find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + o.name);
    s = s.slice(0, i) + o.find + o.add + s.slice(i + o.find.length);
    console.log('patched: ' + rel + ' :: ' + o.name);
  }
  fs.writeFileSync(file, s);
}

const SALES_LINE = "const _sales = String(_nums.wa_sales_number || _nums.wa_support_number || '').replace(/[^0-9]/g, '');";

// ---- bot compose block (checkout.js — has `event`, fetches its own en+link) ----
const BLOCK_CO =
"\n    if (event === 'delivered' && o.source === 'bot' && deliveryMsg) {\n" +
"      try {\n" +
"        const _st = await botapi.orderStatus(o.order_no);\n" +
"        const _f = _st && _st.fields;\n" +
"        if (_f && _f.delivery_type) {\n" +
"          const _en0 = (await pool.query(\"SELECT value FROM wa_settings WHERE key='wa_order_notifications_enabled'\")).rows[0];\n" +
"          if (_en0 && _en0.value === '0') return;\n" +
"          const _lk = (await pool.query(\"SELECT whatsapp_identity_id FROM customer_whatsapp_links WHERE customer_id=$1 AND status='ACTIVE' AND is_primary=true LIMIT 1\", [o.customer_id])).rows[0];\n" +
"          if (!_lk) return;\n" +
"          const _pr = (await pool.query('SELECT instructions, warranty FROM products WHERE id=$1', [o.product_id])).rows[0] || {};\n" +
"          const _plw = (await pool.query('SELECT warranty, delivery_instructions FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0] || {};\n" +
"          const _instr = ((_plw.delivery_instructions || '').trim()) || (_pr.instructions || '');\n" +
"          const _warr = ((_plw.warranty || '').trim()) || (_pr.warranty || '');\n" +
"          const _m = deliveryMsg.compose(o, _f, { siteName: 'Galaxy Subz \\u00d7 Zayron', salesNumber: _sales, instructions: _instr, warranty: _warr });\n" +
"          if (_m && _m.main) {\n" +
"            await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:_lk.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.main }, idempotency_key:'ord-'+o.id+'-delivered' });\n" +
"            if (_m.followup) await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:_lk.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.followup }, idempotency_key:'ord-'+o.id+'-instructions', delay_seconds:4 });\n" +
"            return;\n" +
"          }\n" +
"        }\n" +
"      } catch (e) { /* fall back to the generic path below */ }\n" +
"    }";

// ---- bot compose block (deliver.js — always the delivered notify; reuses `link`, SITE) ----
const BLOCK_DV =
"\n      if (o.source === 'bot' && deliveryMsg) {\n" +
"        try {\n" +
"          const _st = await botapi.orderStatus(o.order_no);\n" +
"          const _f = _st && _st.fields;\n" +
"          if (_f && _f.delivery_type) {\n" +
"            const _pr = (await pool.query('SELECT instructions, warranty FROM products WHERE id=$1', [o.product_id])).rows[0] || {};\n" +
"            const _plw = (await pool.query('SELECT warranty, delivery_instructions FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0] || {};\n" +
"            const _instr = ((_plw.delivery_instructions || '').trim()) || (_pr.instructions || '');\n" +
"            const _warr = ((_plw.warranty || '').trim()) || (_pr.warranty || '');\n" +
"            const _m = deliveryMsg.compose(o, _f, { siteName: SITE, salesNumber: _sales, instructions: _instr, warranty: _warr });\n" +
"            if (_m && _m.main) {\n" +
"              await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:link.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.main }, idempotency_key:'ord-'+o.id+'-delivered' });\n" +
"              if (_m.followup) await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:link.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.followup }, idempotency_key:'ord-'+o.id+'-instructions', delay_seconds:4 });\n" +
"              return;\n" +
"            }\n" +
"          }\n" +
"        } catch (e) { /* fall back to the generic path below */ }\n" +
"      }";

edit('routes/checkout.js', [
  { name: 'require-deliveryMsg', guard: "require('../lib/deliveryMsg')",
    find: "const STATUS_MAP = { genuine: 'paid', pending: 'verifying', lost_race: 'review', ambiguous: 'review', fraud_consumed: 'rejected' };",
    add: "\n  let deliveryMsg = null; try { deliveryMsg = require('../lib/deliveryMsg'); } catch (e) { deliveryMsg = null; }" },
  { name: 'bot-compose', guard: "o.source === 'bot' && deliveryMsg", find: SALES_LINE, add: BLOCK_CO }
]);

edit('lib/deliver.js', [
  { name: 'require-deliveryMsg', guard: "require('./deliveryMsg')",
    find: "let nfGate = null; try { nfGate = require('./netflixGate'); } catch (e) { nfGate = null; }",
    add: "\nlet deliveryMsg = null; try { deliveryMsg = require('./deliveryMsg'); } catch (e) { deliveryMsg = null; }" },
  { name: 'bot-compose', guard: "o.source === 'bot' && deliveryMsg", find: SALES_LINE, add: BLOCK_DV }
]);

console.log('PREMSG-BOT PATCH OK');
