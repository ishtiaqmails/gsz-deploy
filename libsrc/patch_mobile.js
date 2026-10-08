'use strict';
/* Global mobile compatibility: stop any page-level horizontal scroll, and make
   every wide table card scroll sideways (so right-hand columns are reachable on
   phones). One intentional responsive rule, applied via the shared shell. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_mobile.js <ROOT>'); process.exit(1); }
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

const MOBILE = "\n/*mobile-scroll*/\n" +
"html,body{max-width:100%;overflow-x:hidden}\n" +
".card[style*=\"overflow:hidden\"]{overflow-x:auto!important}\n" +
"@media(max-width:860px){ .card[style*=\"overflow:hidden\"] table{min-width:560px} }\n" +
"@media(max-width:860px){ .content{padding-left:14px;padding-right:14px} }\n";

patch('views/admin/_shell_top.ejs', [{
  name: 'mobile-scroll', guard: '/*mobile-scroll*/',
  find: '</style>', replace: MOBILE + '</style>'
}]);
console.log('MOBILE PATCH OK');
