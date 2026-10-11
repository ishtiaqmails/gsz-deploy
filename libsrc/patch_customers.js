'use strict';
/* Wire the Customers admin section:
   - server.js: mount routes/adminCustomers.js (after adminInventory)
   - views/admin/_shell_top.ejs: add a "Customers" sidebar link (after Inventory)
   - routes/account.js: block a suspended customer at login
   Idempotent; aborts if an anchor is missing or not unique. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_customers.js <ROOT>'); process.exit(1); }

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

const SV_FIND = "const adminInventoryRouter = require('./routes/adminInventory')(pool);\napp.use('/admin', adminInventoryRouter);";
const SV_REPL = SV_FIND + "\nconst adminCustomersRouter = require('./routes/adminCustomers')(pool);\napp.use('/admin', adminCustomersRouter);";

const NAV_FIND = "    <a href=\"/admin/inventory\" class=\"<%= on('inventory') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M3 7l9-4 9 4-9 4-9-4z\"/><path d=\"M3 7v10l9 4 9-4V7\"/><path d=\"M12 11v10\"/></svg>Inventory</a>";
const NAV_REPL = NAV_FIND + "\n    <a href=\"/admin/customers\" class=\"<%= on('customers') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2\"/><circle cx=\"9\" cy=\"7\" r=\"4\"/><path d=\"M22 21v-2a4 4 0 0 0-3-3.87\"/><path d=\"M16 3.13a4 4 0 0 1 0 7.75\"/></svg>Customers</a>";

const ACC_FIND = "await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]);";
const ACC_REPL = "if (c.blocked) return re('This account has been suspended. Please contact support.');\n      " + ACC_FIND;

patch('server.js', [
  { name: 'mount-admin-customers', guard: 'routes/adminCustomers', find: SV_FIND, replace: SV_REPL }
]);
patch('views/admin/_shell_top.ejs', [
  { name: 'customers-nav', guard: '/admin/customers', find: NAV_FIND, replace: NAV_REPL }
]);
patch('routes/account.js', [
  { name: 'login-blocked-check', guard: 'c.blocked) return re(', find: ACC_FIND, replace: ACC_REPL }
]);

console.log('ALL PATCHES APPLIED');
