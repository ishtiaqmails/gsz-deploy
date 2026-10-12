'use strict';
/* Bump the static asset cache-buster (?v=NN on /static/js/app.js and
   /static/css/app.css) so browsers fetch freshly-changed JS/CSS.
   Re-runnable: each run increments the current version by 1.
   Edits views/partials/store_top.ejs and views/partials/store_bottom.ejs. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_assetver.js <ROOT>'); process.exit(1); }
const files = ['views/partials/store_top.ejs', 'views/partials/store_bottom.ejs'].map(f => path.join(ROOT, f));
const RE = /(app\.(?:css|js)\?v=)(\d+)/g;

let cur = null;
for (const f of files) {
  const s = fs.readFileSync(f, 'utf8');
  let m; const r = new RegExp(RE.source, 'g');
  while ((m = r.exec(s))) { const n = parseInt(m[2], 10); if (cur === null || n > cur) cur = n; }
}
if (cur === null) throw new Error('ANCHOR MISS: no app.(css|js)?v=NN found');
const next = cur + 1;
for (const f of files) {
  const s = fs.readFileSync(f, 'utf8');
  const out = s.replace(RE, (_m, p1) => p1 + next);
  fs.writeFileSync(f, out);
}
console.log('ASSET VERSION BUMPED: ' + cur + ' -> ' + next);
