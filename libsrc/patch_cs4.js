'use strict';
/* CS-4 patch: mount the sitemap/robots router in server.js BEFORE all '/'-mounted
   routers (so nothing can intercept /sitemap.xml or /robots.txt). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_cs4.js <ROOT>'); process.exit(1); }
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

patch('server.js', [{
  name: 'sitemap-mount',
  guard: "require('./routes/sitemap')",
  find: "const adminRouter = require('./routes/admin')(pool);\napp.use('/admin', adminRouter);",
  replace: "const sitemapRouter = require('./routes/sitemap')(pool);\napp.use('/', sitemapRouter);\nconst adminRouter = require('./routes/admin')(pool);\napp.use('/admin', adminRouter);"
}]);

console.log('CS4 PATCH OK');
