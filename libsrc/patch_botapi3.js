'use strict';
/* Adds/updates iptvLookup() in lib/botapi.js so the Hub's "Renew IPTV Subscription" flow can
   check a line's current expiry before paying. Bot side: POST /api/iptv-lookup -> { ok, found,
   username, expiry, ... }. Read-only, no credits. Some panel searches (login + lookup) are slow,
   so the client timeout is generous (40s). Re-appliable: replaces any prior iptvLookup line. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_botapi3.js <botapi.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

const NEWFN = "function iptvLookup(body) { return req('POST', '/api/iptv-lookup', body || {}, 40000); }";

// remove any prior iptvLookup function line so the timeout stays current on re-run
s = s.replace(/\n?function iptvLookup\(body\) \{ return req\('POST', '\/api\/iptv-lookup', body \|\| \{\}, \d+\); \}/g, '');

const anchor = "function renewStatus(rid) { return req('GET', '/api/renew-status/' + encodeURIComponent(rid), null, 8000); }";
if (s.indexOf(anchor) < 0) throw new Error('ANCHOR MISS: renewStatus line not found in botapi.js');
s = s.replace(anchor, anchor + "\n" + NEWFN);

const expRe = /module\.exports\s*=\s*\{([\s\S]*?)\};/;
const m = s.match(expRe);
if (!m) throw new Error('ANCHOR MISS: module.exports object not found in botapi.js');
if (m[1].indexOf('iptvLookup') < 0) {
  const inner = m[1].replace(/\s*$/, '');
  const newInner = inner + (inner.trim().endsWith(',') ? '' : ',') + ' iptvLookup ';
  s = s.replace(expRe, 'module.exports = {' + newInner + '};');
}

fs.writeFileSync(file, s);
console.log('patched: iptvLookup present (40s timeout)');
console.log('BOTAPI3 PATCH OK');
