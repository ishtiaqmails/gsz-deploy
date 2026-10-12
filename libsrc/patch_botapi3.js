'use strict';
/* Adds iptvLookup() to lib/botapi.js so the Hub's "Renew IPTV Subscription" flow can check a
   line's current expiry before paying. Bot side: POST /api/iptv-lookup { sku|panel_id, raw,
   username?, password? } -> { ok, found, username, expiry, ... }. Read-only, no credits.
   Idempotent: skips if iptvLookup already present. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_botapi3.js <botapi.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('iptvLookup') >= 0) { console.log('skip (already): iptvLookup present'); console.log('BOTAPI3 PATCH OK'); process.exit(0); }

const anchor = "function renewStatus(rid) { return req('GET', '/api/renew-status/' + encodeURIComponent(rid), null, 8000); }";
if (s.indexOf(anchor) < 0) throw new Error('ANCHOR MISS: renewStatus line not found in botapi.js');
const fn = "\nfunction iptvLookup(body) { return req('POST', '/api/iptv-lookup', body || {}, 15000); }";
s = s.replace(anchor, anchor + fn);

const expRe = /module\.exports\s*=\s*\{([\s\S]*?)\};/;
const m = s.match(expRe);
if (!m) throw new Error('ANCHOR MISS: module.exports object not found in botapi.js');
if (m[1].indexOf('iptvLookup') < 0) {
  const inner = m[1].replace(/\s*$/, '');
  const newInner = inner + (inner.trim().endsWith(',') ? '' : ',') + ' iptvLookup ';
  s = s.replace(expRe, 'module.exports = {' + newInner + '};');
}

fs.writeFileSync(file, s);
console.log('patched: added iptvLookup to botapi');
console.log('BOTAPI3 PATCH OK');
