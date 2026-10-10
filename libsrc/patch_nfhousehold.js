'use strict';
/* Add updateHousehold() to lib/nfPortal.js — "Update Household" runs through the Netflix
   Accounts Portal (not the reseller bot / gsz-api). Mirrors assign(): same post() helper,
   same x-nf-read-key auth, fail-safe (never throws). Portal side: POST /internal/household
   { order_no, whatsapp } -> { ok:true } | { ok:false, reason }.
   Idempotent: skips if present. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_nfhousehold.js <nfPortal.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('updateHousehold') >= 0) { console.log('skip (already): updateHousehold present'); console.log('NFHOUSEHOLD PATCH OK'); process.exit(0); }

const anchor = "function get(path) {";
if (s.indexOf(anchor) < 0) throw new Error('ANCHOR MISS: get(path) not found in nfPortal.js');
const fn =
"async function updateHousehold(o) {\n" +
"  o = o || {};\n" +
"  const r = await post('/internal/household', { order_no: o.order_no || '', whatsapp: o.whatsapp || '' });\n" +
"  if (r.status === 200 && r.json && r.json.ok) return Object.assign({ ok: true }, r.json);\n" +
"  return { ok: false, status: r.status, reason: (r.json && (r.json.reason || r.json.error)) || ('http_' + r.status) };\n" +
"}\n";
s = s.replace(anchor, fn + anchor);

const expOld = "module.exports = { assign, stock, configured };";
if (s.indexOf(expOld) < 0) throw new Error('ANCHOR MISS: module.exports not found in nfPortal.js');
s = s.replace(expOld, "module.exports = { assign, stock, configured, updateHousehold };");

fs.writeFileSync(file, s);
console.log('patched: added nfPortal.updateHousehold');
console.log('NFHOUSEHOLD PATCH OK');
