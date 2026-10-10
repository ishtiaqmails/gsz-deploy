'use strict';
/* Admin product save: persist the Renewable flag. Piggybacks on the second products UPDATE
   (which runs for both create and edit, after id is set). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodrenewable.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('renewable=$6') >= 0) { console.log('skip (already): renewable in save'); console.log('PRODRENEWABLE PATCH OK'); process.exit(0); }

const old = "await c.query('UPDATE products SET offer_ends=$1, offer_label=$2, warranty=$4, instructions=$5 WHERE id=$3', [ (b.offer_ends||'').trim()||null, (b.offer_label||'').trim()||null, id, (b.warranty||'').trim()||null, (b.instructions||'').trim()||null ]);";
const neu = "await c.query('UPDATE products SET offer_ends=$1, offer_label=$2, warranty=$4, instructions=$5, renewable=$6 WHERE id=$3', [ (b.offer_ends||'').trim()||null, (b.offer_label||'').trim()||null, id, (b.warranty||'').trim()||null, (b.instructions||'').trim()||null, (b.renewable? true : false) ]);";
if (s.indexOf(old) < 0) throw new Error('ANCHOR MISS: product offer/warranty UPDATE line not found in adminCatalog.js');
s = s.replace(old, neu);
fs.writeFileSync(file, s);
console.log('patched: adminCatalog save now persists renewable');
console.log('PRODRENEWABLE PATCH OK');
