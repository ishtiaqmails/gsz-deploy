'use strict';
/* Wire the Reseller Panels feature into existing files:
     1) server.js       — mount routes/adminResellers after adminCatalog
     2) routes/pages.js — load active panels in the /resellers route and pass to the view
     3) views/admin/_shell_top.ejs — add the "Reseller Panels" nav link after Reviews
   Single-line anchors, guarded + idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_resellers.js <ROOT>'); process.exit(1); }

function sub(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name + ' in ' + file);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name + ' in ' + file);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

/* 1) server.js — mount after adminCatalog */
sub(path.join(ROOT, 'server.js'), 'server:mount', 'adminResellersRouter',
  "app.use('/admin', adminCatalogRouter);",
  "app.use('/admin', adminCatalogRouter);\nconst adminResellersRouter = require('./routes/adminResellers')(pool);\napp.use('/admin', adminResellersRouter);");

/* 2) routes/pages.js — load panels in the /resellers route */
sub(path.join(ROOT, 'routes/pages.js'), 'pages:panels', 'panels: _panels',
  "res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName }, s));",
  "let _panels=[]; try{ _panels=(await pool.query(\"SELECT id,name,badge,tagline,features,image_url,wa_text,currency,tiers FROM reseller_panels WHERE active ORDER BY sort, id\")).rows; }catch(e){ _panels=[]; }\n      res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName, panels: _panels }, s));");

/* 3) admin nav — add link after Reviews */
sub(path.join(ROOT, 'views/admin/_shell_top.ejs'), 'nav:link', 'href="/admin/resellers"',
  "</svg>Reviews</a>",
  "</svg>Reviews</a>\n    <a href=\"/admin/resellers\" class=\"<%= on('resellers') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M3 21V9l9-6 9 6v12\"/><path d=\"M9 21v-6h6v6\"/></svg>Reseller Panels</a>");

console.log('RESELLERS PATCH OK');
