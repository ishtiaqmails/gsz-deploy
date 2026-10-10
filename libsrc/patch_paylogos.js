'use strict';
/* Attach each payment method's logo (payment_methods.logo) to the pay-methods response by key,
   so the checkout can render logo tiles. Works whether the methods came from the bot or the local
   table (both carry `key`). Inserted right before the pay-methods res.json in routes/account.js.
   Idempotent (guard: pay-logos-by-key). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_paylogos.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('pay-logos-by-key') >= 0) { console.log('skip (already): pay-logos'); console.log('PAYLOGOS PATCH OK'); process.exit(0); }

const ANCHOR = "    res.json({ ok:true, methods });";
const INJECT =
"    try{ /* pay-logos-by-key */ const _lg=(await pool.query(\"SELECT key, logo FROM payment_methods WHERE logo IS NOT NULL AND logo<>''\")).rows; const _lm={}; _lg.forEach(function(r){ _lm[r.key]=r.logo; }); methods.forEach(function(m){ if(_lm[m.key]) m.logo=_lm[m.key]; }); }catch(e){}\n";

const i = s.indexOf(ANCHOR);
if (i < 0) throw new Error('ANCHOR MISS: pay-methods res.json not found in account.js');
s = s.slice(0, i) + INJECT + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: pay-methods now returns a logo per method');
console.log('PAYLOGOS PATCH OK');
