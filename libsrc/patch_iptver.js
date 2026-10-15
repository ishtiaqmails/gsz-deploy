'use strict';
/* IPTV version label in delivery + admin mirror + warranty fallback.
   Modifies the ALREADY-DEPLOYED premium-delivery blocks in routes/checkout.js and lib/deliver.js:
     1) widen the per-plan SELECT to also fetch bot_sku + version_labels,
     2) resolve the customer's version label (bot_type_labels by sku -> plan version_labels),
        and fall the warranty back to the bot's own warranty when the website has none,
     3) pass versionLabel into deliveryMsg.compose,
     4) save the clean composed credentials into orders.delivered_credentials so the
        admin order page shows exactly what the customer received (not the raw bot blob).
   Single-line anchors (CRLF/indent robust), guarded + idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_iptver.js <ROOT>'); process.exit(1); }

function sub(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name + ' in ' + file);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name + ' in ' + file);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

// Warranty line is the unique, safe anchor in both files (the other `_warr`/SELECT lines differ).
// We do NOT touch the ambiguous SELECT line; instead we fetch bot_sku/version_labels in a
// self-contained query inside the injected resolver, so there is nothing non-unique to match.
const WARR_FIND = "const _warr = ((_plw.warranty || '').trim()) || (_pr.warranty || '');";
const WARR_REPL = "const _warr = ((_plw.warranty || '').trim()) || (_pr.warranty || '') || ((_f && _f.warranty) || '');"
  + " let _vlabel='';"
  + " try{ const _vk=String(o.bot_type||'').trim();"
  + " if(_vk){ const _vp=(await pool.query(\"SELECT bot_sku, version_labels FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1\",[o.product_id,o.plan_label])).rows[0]||{};"
  + " const _btl=(await pool.query(\"SELECT label FROM bot_type_labels WHERE sku=$1 AND type_key=$2 LIMIT 1\",[_vp.bot_sku,_vk])).rows[0];"
  + " if(_btl&&_btl.label){ _vlabel=_btl.label; }"
  + " else { let _vls=_vp.version_labels; if(typeof _vls==='string'){ try{_vls=JSON.parse(_vls);}catch(e){_vls=null;} }"
  + " if(Array.isArray(_vls)){ const _mm=_vls.find(function(v){return v&&v.key===_vk;}); if(_mm&&_mm.label){ _vlabel=_mm.label; } } } } }catch(e){}";

const CRED_SAVE = " if (_m.credentials) { try { await pool.query(\"UPDATE orders SET delivered_credentials=$1 WHERE id=$2\", [_m.credentials, o.id]); } catch(e){} }";

// ---- routes/checkout.js ----
const CO = path.join(ROOT, 'routes/checkout.js');
sub(CO, 'co:resolve', 'let _vlabel=', WARR_FIND, WARR_REPL);
sub(CO, 'co:compose', 'versionLabel: _vlabel',
  "const _m = deliveryMsg.compose(o, _f, { siteName: 'Galaxy Subz \\u00d7 Zayron', salesNumber: _sales, instructions: _instr, warranty: _warr });",
  "const _m = deliveryMsg.compose(o, _f, { siteName: 'Galaxy Subz \\u00d7 Zayron', salesNumber: _sales, instructions: _instr, warranty: _warr, versionLabel: _vlabel });");
sub(CO, 'co:credsave', 'UPDATE orders SET delivered_credentials=$1 WHERE id=$2',
  "await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:_lk.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.main }, idempotency_key:'ord-'+o.id+'-delivered' });",
  "await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:_lk.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.main }, idempotency_key:'ord-'+o.id+'-delivered' });" + CRED_SAVE);

// ---- lib/deliver.js ----
const DV = path.join(ROOT, 'lib/deliver.js');
sub(DV, 'dv:resolve', 'let _vlabel=', WARR_FIND, WARR_REPL);
sub(DV, 'dv:compose', 'versionLabel: _vlabel',
  "const _m = deliveryMsg.compose(o, _f, { siteName: SITE, salesNumber: _sales, instructions: _instr, warranty: _warr });",
  "const _m = deliveryMsg.compose(o, _f, { siteName: SITE, salesNumber: _sales, instructions: _instr, warranty: _warr, versionLabel: _vlabel });");
sub(DV, 'dv:credsave', 'UPDATE orders SET delivered_credentials=$1 WHERE id=$2',
  "await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:link.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.main }, idempotency_key:'ord-'+o.id+'-delivered' });",
  "await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:link.whatsapp_identity_id, template_key:'whatsapp.raw', vars:{ body:_m.main }, idempotency_key:'ord-'+o.id+'-delivered' });" + CRED_SAVE);

console.log('IPTV-VERSION PATCH OK');
