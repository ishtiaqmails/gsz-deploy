'use strict';
/* Wire the WhatsApp Connection admin section:
   - server.js: mount routes/adminWhatsapp.js (after adminCustomers)
   - views/admin/_shell_top.ejs: add a "WhatsApp" sidebar link (after Customers)
   Idempotent; aborts if an anchor is missing or not unique. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_whatsapp_admin.js <ROOT>'); process.exit(1); }

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

const SV_FIND = "const adminCustomersRouter = require('./routes/adminCustomers')(pool);\napp.use('/admin', adminCustomersRouter);";
const SV_REPL = SV_FIND + "\nconst adminWhatsappRouter = require('./routes/adminWhatsapp')(pool);\napp.use('/admin', adminWhatsappRouter);";

const NAV_FIND = "    <a href=\"/admin/customers\" class=\"<%= on('customers') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2\"/><circle cx=\"9\" cy=\"7\" r=\"4\"/><path d=\"M22 21v-2a4 4 0 0 0-3-3.87\"/><path d=\"M16 3.13a4 4 0 0 1 0 7.75\"/></svg>Customers</a>";
const NAV_REPL = NAV_FIND + "\n    <a href=\"/admin/whatsapp\" class=\"<%= on('whatsapp') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M21 11.5a8.4 8.4 0 0 1-1.2 4.4L21 21l-5.3-1.4A8.5 8.5 0 1 1 21 11.5Z\"/><path d=\"m8.5 12 2 2 4-4.2\"/></svg>WhatsApp</a>";

patch('server.js', [
  { name: 'mount-admin-whatsapp', guard: 'routes/adminWhatsapp', find: SV_FIND, replace: SV_REPL }
]);
patch('views/admin/_shell_top.ejs', [
  { name: 'whatsapp-nav', guard: '/admin/whatsapp', find: NAV_FIND, replace: NAV_REPL }
]);

console.log('ALL PATCHES APPLIED');
