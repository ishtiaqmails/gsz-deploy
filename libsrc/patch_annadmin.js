'use strict';
/* #75 Stage 2 — admin Announcements: add stat counts to GET /announcements.
   routes/adminAnnouncements.js. Idempotent; aborts if an anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_annadmin.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminAnnouncements.js');
let s = fs.readFileSync(file, 'utf8');

function edit(name, guard, find, repl) {
  if (guard && s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + repl + s.slice(i + find.length);
  console.log('patched: ' + name);
}

const COUPONS_LINE = "    const coupons = (await pool.query('SELECT code FROM coupons WHERE active ORDER BY id DESC')).rows;";
const STATS = "\n    let stats = { total: 0, promos: 0, wa: 0, month: 0 };\n" +
  "    try { stats = (await pool.query(\"SELECT count(*)::int total, count(*) FILTER (WHERE kind='promo')::int promos, count(*) FILTER (WHERE wa_sent)::int wa, count(*) FILTER (WHERE created_at > now()-interval '30 days')::int month FROM announcements\")).rows[0] || stats; } catch (e) {}";
edit('stats query', "let stats = { total:", COUPONS_LINE, COUPONS_LINE + STATS);

edit('stats in render', "rows, products, coupons, stats,",
  "res.render('admin/announcements', { rows, products, coupons, flash: req.query.ok || null });",
  "res.render('admin/announcements', { rows, products, coupons, stats, flash: req.query.ok || null });");

fs.writeFileSync(file, s);
console.log('ANN ADMIN STATS PATCH OK');
