'use strict';
/* pay-logos v3: attach each payment method's logo AND order it by the GSZ-side sort, both from the
   payment_logos registry (key -> logo, sort). Works for bot-sourced methods and the local fallback.
   Inserted before the pay-methods res.json in routes/account.js. Idempotent; upgrades v1/v2 to v3. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_paylogos.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const V3 = "    try{ /* pay-logos-v3 */ const _lg=(await pool.query('SELECT key, logo, sort FROM payment_logos')).rows; const _lm={},_sm={}; _lg.forEach(function(r){ _lm[r.key]=r.logo; _sm[r.key]=(r.sort==null?100:r.sort); }); methods.forEach(function(m){ if(_lm[m.key]) m.logo=_lm[m.key]; }); methods.sort(function(a,b){ return (_sm[a.key]==null?100:_sm[a.key])-(_sm[b.key]==null?100:_sm[b.key]); }); }catch(e){}\n";
const ANCHOR = "    res.json({ ok:true, methods });";

if (s.indexOf('pay-logos-v3') >= 0) { console.log('skip (already v3)'); console.log('PAYLOGOS PATCH OK'); process.exit(0); }

// strip any earlier single-line inject (v1 by-key / v2)
const before = s;
s = s.replace(/^[ \t]*try\{ \/\* pay-logos-(by-key|v2) \*\/[^\n]*\}catch\(e\)\{\}\n/m, '');
if (s !== before) console.log('removed earlier pay-logos inject');

const i = s.indexOf(ANCHOR);
if (i < 0) throw new Error('ANCHOR MISS: pay-methods res.json not found in account.js');
s = s.slice(0, i) + V3 + s.slice(i);
fs.writeFileSync(file, s);
console.log('injected pay-logos v3 (logo + order by payment_logos.sort)');
console.log('PAYLOGOS PATCH OK');
