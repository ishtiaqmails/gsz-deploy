'use strict';
/* Mount the public review router in server.js. Single-line anchor, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_reviews_r2b.js <ROOT>'); process.exit(1); }
const SV = path.join(ROOT, 'server.js');
let s = fs.readFileSync(SV, 'utf8');
if (s.indexOf("require('./routes/reviewpublic')") >= 0) { console.log('skip (already): reviewpublic-mount'); process.exit(0); }
const anchor = "app.use('/', contentRouter);";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: contentRouter mount');
if (s.indexOf(anchor, i + anchor.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: contentRouter mount');
const add = anchor + "\n  const reviewRouter = require('./routes/reviewpublic')(pool); app.use('/', reviewRouter);";
fs.writeFileSync(SV, s.slice(0, i) + add + s.slice(i + anchor.length));
console.log('patched: reviewpublic-mount');
