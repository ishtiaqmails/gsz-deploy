'use strict';
/* HOTFIX_PAINT — restore $$ in paintPrices (an early Stage-2 .replace() turned $$ into $, which
   crashed app.js: "$(...).forEach is not a function"). split/join only — never .replace (which
   would re-mangle $$). Anchored with the leading { so there is no $/$$ substring overlap. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const F = 'public/js/app.js';
const OLD = "{$('[data-pkr]',root)";
const NEU = "{$$('[data-pkr]',root)";
let s = fs.readFileSync(path.join(ROOT, F), 'utf8');
if (s.indexOf(NEU) >= 0) { console.log('HOTFIX_PAINT already applied'); process.exit(0); }
const n = s.split(OLD).length - 1;
if (n === 0) throw new Error('ANCHOR MISSING: ' + OLD);
s = s.split(OLD).join(NEU);
fs.writeFileSync(path.join(ROOT, F), s);
console.log('HOTFIX_PAINT applied=' + n);
