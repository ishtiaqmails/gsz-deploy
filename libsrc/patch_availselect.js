'use strict';
/* Fix: add avail_note to the product-page planRows SELECT (anchor-independent of trailing columns
   like ,popular). The plan map already reads r.avail_note. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_availselect.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/products.js');
let s = fs.readFileSync(file, 'utf8');
const OLD = "avail_from, avail_until, warranty, ";
const NEW = "avail_from, avail_until, warranty, avail_note, ";
if (s.indexOf("warranty, avail_note,") >= 0) { console.log('availselect: present (skip)'); }
else if (s.indexOf(OLD) >= 0) { s = s.replace(OLD, NEW); fs.writeFileSync(file, s); console.log('availselect: avail_note added to planRows SELECT'); }
else { console.log('availselect: anchor missing (skip)'); }
console.log('AVAILSELECT OK');
