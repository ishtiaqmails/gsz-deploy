'use strict';
/* Trials can't be extended (only converted to paid), so ensure lib/botapi.js has NO extendTrial hook.
   Removes the function line and its module.exports entry if a previous build added them. Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_botapi.js <botapi.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('extendTrial') < 0) { console.log('ok: no extendTrial present'); console.log('BOTAPI PATCH OK'); process.exit(0); }

// remove the function definition line (with its leading newline)
s = s.replace(/\n?function extendTrial\(payload\) \{ return req\('POST', '\/api\/extend-trial', payload, 15000\); \}/g, '');
// remove from module.exports (handles ', extendTrial' or 'extendTrial, ' or lone)
s = s.replace(/,\s*extendTrial\b/g, '').replace(/\bextendTrial\s*,\s*/g, '').replace(/\bextendTrial\b/g, '');

fs.writeFileSync(file, s);
console.log('patched: removed extendTrial from botapi (trials convert-only)');
console.log('BOTAPI PATCH OK');
