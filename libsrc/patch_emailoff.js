'use strict';
/* Disable the payment-confirmed / order-received email entirely.
   Single-point: emailOrder(o, kind) returns immediately when kind === 'confirm',
   so no caller (checkout match, partial delivery, etc.) can send it.
   Customers only ever receive the final 'Your order is ready' (delivered) email.
   Single-line anchor, CRLF/indent-robust, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_emailoff.js <ROOT>'); process.exit(1); }
const CO = path.join(ROOT, 'routes/checkout.js');

let s = fs.readFileSync(CO, 'utf8');
if (s.indexOf('EMAIL_CONFIRM_OFF') >= 0) { console.log('skip (already): email-confirm-off'); process.exit(0); }
const find = 'async function emailOrder(o, kind) {';
const i = s.indexOf(find);
if (i < 0) throw new Error('ANCHOR MISS: emailOrder signature');
if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: emailOrder signature');
const repl = find + "\n    if (kind === 'confirm') return; // EMAIL_CONFIRM_OFF — payment-confirmed email disabled";
fs.writeFileSync(CO, s.slice(0, i) + repl + s.slice(i + find.length));
console.log('patched: email-confirm-off');
