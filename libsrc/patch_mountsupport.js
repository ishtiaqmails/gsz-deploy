'use strict';
/* Mount the support router at /api/support (after the sitemap router, before admin). server.js.
   Idempotent, anchored. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_mountsupport.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'server.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('routes/support') >= 0) { console.log('skip (already): support mount'); console.log('MOUNT OK'); process.exit(0); }

const A = "app.use('/', sitemapRouter);";
if (s.indexOf(A) < 0) throw new Error('ANCHOR MISS: sitemap router mount');
s = s.replace(A, A + "\nconst supportRouter = require('./routes/support')(pool);\napp.use('/api/support', supportRouter);");

fs.writeFileSync(file, s);
console.log('mounted /api/support');
console.log('MOUNT OK');
