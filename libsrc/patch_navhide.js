'use strict';
/* Hide "Bot mapping" and "Version names" from the admin nav — the product model now covers both
   (per-plan mapping + version labels). Routes stay reachable; only the nav links are removed.
   Patches views/admin/_shell_top.ejs. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_navhide.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/admin/_shell_top.ejs');
let s = fs.readFileSync(file, 'utf8');
let n = 0;
[/\s*<a href="\/admin\/mapping"[\s\S]*?<\/a>/, /\s*<a href="\/admin\/labels"[\s\S]*?<\/a>/].forEach(function(re){
  if (re.test(s)) { s = s.replace(re, ''); n++; }
});
if (n) { fs.writeFileSync(file, s); console.log('navhide: removed ' + n + ' nav link(s)'); }
else { console.log('navhide: already removed (skip)'); }
console.log('NAVHIDE OK');
