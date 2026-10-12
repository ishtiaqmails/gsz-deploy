'use strict';
/* lib/botapi.js bridge for the Hub "Renew IPTV Subscription" lookup. Read-only, no credits.
   Forward-compatible with both the sync and the async gsz-api lookup:
     iptvLookup(body)      -> POST /api/iptv-lookup          (sync result, OR {pending, lookup_id})
     iptvLookupStatus(id)  -> GET  /api/iptv-lookup-status?id=<id>   (async poll)
   Slow browser-scrape panels can take 15-45s, so the POST timeout is generous for the
   transition; once the bot is async the POST returns instantly and polling takes over.
   Re-appliable: replaces any prior definitions so timeouts/signatures stay current. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_botapi3.js <botapi.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

const FN1 = "function iptvLookup(body) { return req('POST', '/api/iptv-lookup', body || {}, 50000); }";
const FN2 = "function iptvLookupStatus(id) { return req('GET', '/api/iptv-lookup-status?id=' + encodeURIComponent(id), null, 12000); }";

// remove any prior definitions so this patch is re-appliable
s = s.replace(/\n?function iptvLookup\(body\) \{ return req\('POST', '\/api\/iptv-lookup', body \|\| \{\}, \d+\); \}/g, '');
s = s.replace(/\n?function iptvLookupStatus\(id\) \{ return req\('GET', '\/api\/iptv-lookup-status\?id=' \+ encodeURIComponent\(id\), null, \d+\); \}/g, '');

const anchor = "function renewStatus(rid) { return req('GET', '/api/renew-status/' + encodeURIComponent(rid), null, 8000); }";
if (s.indexOf(anchor) < 0) throw new Error('ANCHOR MISS: renewStatus line not found in botapi.js');
s = s.replace(anchor, anchor + "\n" + FN1 + "\n" + FN2);

const expRe = /module\.exports\s*=\s*\{([\s\S]*?)\};/;
const m = s.match(expRe);
if (!m) throw new Error('ANCHOR MISS: module.exports object not found in botapi.js');
let inner = m[1];
['iptvLookup', 'iptvLookupStatus'].forEach(function(name){
  if (inner.indexOf(name) < 0) { inner = inner.replace(/\s*$/, ''); inner = inner + (inner.trim().endsWith(',') ? '' : ',') + ' ' + name + ' '; }
});
s = s.replace(expRe, 'module.exports = {' + inner + '};');

fs.writeFileSync(file, s);
console.log('patched: iptvLookup + iptvLookupStatus present');
console.log('BOTAPI3 PATCH OK');
