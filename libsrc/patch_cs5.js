'use strict';
/* CS-5 patches: add a "Content Studio" nav group to the admin sidebar
   (views/admin/_shell_top.ejs) and mount routes/csAdmin.js at /admin. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_cs5.js <ROOT>'); process.exit(1); }
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

const nav =
  '\n    <div class="grp">Content Studio</div>' +
  '\n    <a href="/admin/cstudio" class="<%= on(\'cs_dash\') %>"><svg viewBox="0 0 24 24"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>Overview</a>' +
  '\n    <a href="/admin/cstudio/posts" class="<%= on(\'cs_posts\') %>"><svg viewBox="0 0 24 24"><path d="M8 3h8l4 4v14H4V3z"/><path d="M8 9h8M8 13h8M8 17h5"/></svg>Posts</a>' +
  '\n    <a href="/admin/cstudio/import" class="<%= on(\'cs_import\') %>"><svg viewBox="0 0 24 24"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>Import</a>' +
  '\n    <a href="/admin/cstudio/redirects" class="<%= on(\'cs_redirects\') %>"><svg viewBox="0 0 24 24"><path d="M3 7h12l-3-3"/><path d="M21 17H9l3 3"/></svg>Redirects</a>';

patch('views/admin/_shell_top.ejs', [{
  name: 'cstudio-nav', guard: "on('cs_dash')",
  find: 'Marketing</a>', replace: 'Marketing</a>' + nav
}]);

patch('server.js', [{
  name: 'csadmin-mount', guard: "require('./routes/csAdmin')",
  find: "const adminAnnouncementsRouter = require('./routes/adminAnnouncements')(pool);\napp.use('/admin', adminAnnouncementsRouter);",
  replace: "const adminAnnouncementsRouter = require('./routes/adminAnnouncements')(pool);\napp.use('/admin', adminAnnouncementsRouter);\nconst csAdminRouter = require('./routes/csAdmin')(pool);\napp.use('/admin', csAdminRouter);"
}]);

console.log('CS5 PATCHES OK');
