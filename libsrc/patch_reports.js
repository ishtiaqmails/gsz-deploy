'use strict';
/* Wire the Reports section:
   - server.js: mount routes/adminReports.js (after adminReset)
   - views/admin/_shell_top.ejs: add a "Reports" link under OVERVIEW (after Dashboard)
   Idempotent; aborts if an anchor is missing or not unique. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_reports.js <ROOT>'); process.exit(1); }

function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.repl + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

const SV_FIND = "const adminResetRouter = require('./routes/adminReset')(pool);\napp.use('/admin', adminResetRouter);";
const SV_REPL = SV_FIND + "\nconst adminReportsRouter = require('./routes/adminReports')(pool);\napp.use('/admin', adminReportsRouter);";

const NAV_FIND = "    <a href=\"/admin\" class=\"<%= on('dashboard') %>\"><svg viewBox=\"0 0 24 24\"><rect x=\"3\" y=\"3\" width=\"7\" height=\"7\" rx=\"1.5\"/><rect x=\"14\" y=\"3\" width=\"7\" height=\"7\" rx=\"1.5\"/><rect x=\"3\" y=\"14\" width=\"7\" height=\"7\" rx=\"1.5\"/><rect x=\"14\" y=\"14\" width=\"7\" height=\"7\" rx=\"1.5\"/></svg>Dashboard</a>";
const NAV_REPL = NAV_FIND + "\n    <a href=\"/admin/reports\" class=\"<%= on('reports') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M3 3v18h18\"/><rect x=\"7\" y=\"11\" width=\"3\" height=\"7\"/><rect x=\"12\" y=\"7\" width=\"3\" height=\"11\"/><rect x=\"17\" y=\"4\" width=\"3\" height=\"14\"/></svg>Reports</a>";

patch('server.js', [
  { name: 'mount-admin-reports', guard: 'routes/adminReports', find: SV_FIND, repl: SV_REPL }
]);
patch('views/admin/_shell_top.ejs', [
  { name: 'reports-nav', guard: '/admin/reports', find: NAV_FIND, repl: NAV_REPL }
]);

console.log('ALL PATCHES APPLIED');
