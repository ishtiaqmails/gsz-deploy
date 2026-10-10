'use strict';
/* Attach each payment method's logo to the pay-methods response, BY KEY, from the dedicated
   payment_logos registry (key -> logo). Works for bot-sourced methods (the real source) and the
   local fallback alike. Inserted right before the pay-methods res.json in routes/account.js.
   Idempotent, and upgrades the earlier v1 (payment_methods-based) injection to v2. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_paylogos.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const V2 = "    try{ /* pay-logos-v2 */ const _lg=(await pool.query('SELECT key, logo FROM payment_logos')).rows; const _lm={}; _lg.forEach(function(r){ _lm[r.key]=r.logo; }); methods.forEach(function(m){ if(_lm[m.key]) m.logo=_lm[m.key]; }); }catch(e){}\n";
const V1 = "    try{ /* pay-logos-by-key */ const _lg=(await pool.query(\"SELECT key, logo FROM payment_methods WHERE logo IS NOT NULL AND logo<>''\")).rows; const _lm={}; _lg.forEach(function(r){ _lm[r.key]=r.logo; }); methods.forEach(function(m){ if(_lm[m.key]) m.logo=_lm[m.key]; }); }catch(e){}\n";
const ANCHOR = "    res.json({ ok:true, methods });";

if (s.indexOf('pay-logos-v2') >= 0) { console.log('skip (already v2)'); console.log('PAYLOGOS PATCH OK'); process.exit(0); }

if (s.indexOf(V1) >= 0) {
  s = s.replace(V1, V2);
  console.log('upgraded pay-logos v1 -> v2 (payment_logos registry)');
} else {
  const i = s.indexOf(ANCHOR);
  if (i < 0) throw new Error('ANCHOR MISS: pay-methods res.json not found in account.js');
  s = s.slice(0, i) + V2 + s.slice(i);
  console.log('injected pay-logos v2 (payment_logos registry)');
}
fs.writeFileSync(file, s);
console.log('PAYLOGOS PATCH OK');
