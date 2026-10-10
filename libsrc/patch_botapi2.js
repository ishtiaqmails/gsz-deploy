'use strict';
/* Adds updateHousehold() to lib/botapi.js so the Hub's "Update Household" button works.
   The site endpoint /account/tools/household/:no already calls botapi.updateHousehold;
   this supplies the client. Bot side: POST /api/update-household { order_no, whatsapp }.
   If the bot doesn't implement it yet, the call rejects and the UI degrades gracefully.
   Idempotent: skips if updateHousehold already present. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_botapi2.js <botapi.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('updateHousehold') >= 0) { console.log('skip (already): updateHousehold present'); console.log('BOTAPI2 PATCH OK'); process.exit(0); }

// 1) add the function right after renewStatus (a stable, existing one-liner)
const anchor = "function renewStatus(rid) { return req('GET', '/api/renew-status/' + encodeURIComponent(rid), null, 8000); }";
if (s.indexOf(anchor) < 0) throw new Error('ANCHOR MISS: renewStatus line not found in botapi.js');
const fn = "\nfunction updateHousehold(orderNo, whatsapp) { return req('POST', '/api/update-household', { order_no: orderNo, whatsapp: whatsapp || '' }, 15000); }";
s = s.replace(anchor, anchor + fn);

// 2) add to module.exports list (insert before the closing brace of the exports object)
const expRe = /module\.exports\s*=\s*\{([\s\S]*?)\};/;
const m = s.match(expRe);
if (!m) throw new Error('ANCHOR MISS: module.exports object not found in botapi.js');
if (m[1].indexOf('updateHousehold') < 0) {
  const inner = m[1].replace(/\s*$/, '');
  const newInner = inner + (inner.trim().endsWith(',') ? '' : ',') + ' updateHousehold ';
  s = s.replace(expRe, 'module.exports = {' + newInner + '};');
}

fs.writeFileSync(file, s);
console.log('patched: added updateHousehold to botapi');
console.log('BOTAPI2 PATCH OK');
