'use strict';
/* Top marquee text: bold + crisp white (match the product-aware pill) on the new
   premium gradient bar. public/css/app.css. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_marqueebold.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'public/css/app.css');
let s = fs.readFileSync(file, 'utf8');

const GUARD = '/*marqBold*/';
if (s.indexOf(GUARD) >= 0) { console.log('skip (already): marquee bold'); process.exit(0); }

const FIND = '.marquee li{display:flex;align-items:center;gap:8px;color:#cdd3ea;white-space:nowrap}';
const REPL = '.marquee li{/*marqBold*/display:flex;align-items:center;gap:8px;color:#fff;font-weight:700;letter-spacing:.01em;white-space:nowrap}';

const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: .marquee li rule');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: .marquee li');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('MARQUEE BOLD PATCH OK');
