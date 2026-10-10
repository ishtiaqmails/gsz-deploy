'use strict';
/* Add an extendTrial() hook to lib/botapi.js so the website can ask the bot to extend a trial line.
   Mirrors the existing renew()/generateTrial() helpers. The bot implements POST /api/extend-trial;
   until it does, the website degrades gracefully (marks the extend as requested). Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_botapi.js <botapi.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('extendTrial') >= 0) { console.log('skip (already): extendTrial present'); console.log('BOTAPI PATCH OK'); process.exit(0); }

// 1) add the function right after generateTrial(...)
const anchor = "function generateTrial(payload) { return req('POST', '/api/generate-trial', payload, 15000); }";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: generateTrial not found in botapi.js');
const fn = "\nfunction extendTrial(payload) { return req('POST', '/api/extend-trial', payload, 15000); }";
s = s.slice(0, i + anchor.length) + fn + s.slice(i + anchor.length);

// 2) add extendTrial to module.exports
const me = s.match(/module\.exports\s*=\s*\{[^}]*\}/);
if (!me) throw new Error('ANCHOR MISS: module.exports not found in botapi.js');
if (me[0].indexOf('extendTrial') < 0) {
  const updated = me[0].replace(/\}\s*$/, ', extendTrial }');
  s = s.replace(me[0], updated);
}
fs.writeFileSync(file, s);
console.log('patched: added botapi.extendTrial (POST /api/extend-trial)');
console.log('BOTAPI PATCH OK');
