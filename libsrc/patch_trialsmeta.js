'use strict';
/* Add `metadata` to the My Trials page query so trials.ejs can render per-type fields.
   Single-line anchor, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_trialsmeta.js <ROOT>'); process.exit(1); }
const TJ = path.join(ROOT, 'routes/trials.js');
let s = fs.readFileSync(TJ, 'utf8');
const done = 'claimed_at, metadata FROM trial_claims WHERE customer_id=$1 ORDER BY id DESC LIMIT 30';
const find = 'claimed_at FROM trial_claims WHERE customer_id=$1 ORDER BY id DESC LIMIT 30';
if (s.indexOf(done) >= 0) { console.log('skip (already): trials-meta-select'); process.exit(0); }
const i = s.indexOf(find);
if (i < 0) throw new Error('ANCHOR MISS: trials-meta-select');
if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: trials-meta-select');
fs.writeFileSync(TJ, s.slice(0, i) + done + s.slice(i + find.length));
console.log('patched: trials-meta-select');
