'use strict';
/* Reset-proof renew/activation ids. renewal_id/activation_id were derived from o.id
   (the orders serial), which rewinds on TRUNCATE ... RESTART IDENTITY -> after a reset
   they collide with earlier bot runs and the idempotent bot returns the STALE renewal/
   activation. Derive them from o.order_no (already reset-proof via order_no_seq) instead,
   and fall back to that same id as the poll key if the bot returns no request_id. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_renewid.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

patch('routes/checkout.js', [
  {
    name: 'renewal_id-from-order_no',
    guard: "renewal_id: 'ren-' + o.order_no",
    find: "renewal_id: 'ren-' + o.id,",
    replace: "renewal_id: 'ren-' + o.order_no,"
  },
  {
    name: 'renew-poll-key-fallback',
    guard: "(rr && rr.request_id) || ('ren-' + o.order_no)",
    find: "[String((rr && rr.request_id) || ''), o.id]",
    replace: "[String((rr && rr.request_id) || ('ren-' + o.order_no)), o.id]"
  },
  {
    name: 'activation_id-from-order_no',
    guard: "activation_id: 'act-' + o.order_no",
    find: "activation_id: 'act-' + o.id,",
    replace: "activation_id: 'act-' + o.order_no,"
  },
  {
    name: 'activate-poll-key-fallback',
    guard: "(ar && ar.request_id) || ('act-' + o.order_no)",
    find: "[String((ar && ar.request_id) || ''), o.id]",
    replace: "[String((ar && ar.request_id) || ('act-' + o.order_no)), o.id]"
  }
]);
console.log('RENEWID PATCH OK');
