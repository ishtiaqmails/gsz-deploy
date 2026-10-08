'use strict';
/* Fix class collision: the dashboard panel rows used ".drow .main", and the shell
   layout container is also ".main{min-height:100vh}", so each row inherited 100vh.
   Rename the row-content rule to ".drow .rinfo" (markup updated to match). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_rowfix.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/admin/_shell_top.ejs');
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('.drow .rinfo{') >= 0) { console.log('skip (already): rowfix'); process.exit(0); }
const find = '.drow .main{flex:1;min-width:0}';
if (s.indexOf(find) < 0) throw new Error('ANCHOR MISS: .drow .main rule not found');
s = s.replace(find, '.drow .rinfo{flex:1;min-width:0}');
fs.writeFileSync(file, s);
console.log('ROWFIX OK');
