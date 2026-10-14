'use strict';
/* The hub posts the email code as JSON, but /account/tools/email/verify used the urlencoded
   `body` middleware, so req.body.code was empty -> "Enter the 6-digit code" even for a correct
   code. Switch it to express.json (same as /account/tools/profile). Single-line anchor, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_emailverifyjson.js <ROOT>'); process.exit(1); }
const AC = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(AC, 'utf8');
const done = "/account/tools/email/verify', express.json({limit:'8kb'}), requireLogin,";
if (s.indexOf(done) >= 0) { console.log('skip (already): email-verify-json'); process.exit(0); }
const find = "/account/tools/email/verify', body, requireLogin,";
const i = s.indexOf(find);
if (i < 0) throw new Error('ANCHOR MISS: email-verify-json');
if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: email-verify-json');
fs.writeFileSync(AC, s.slice(0, i) + done + s.slice(i + find.length));
console.log('patched: email-verify-json');
