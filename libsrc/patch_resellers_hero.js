'use strict';
/* Reseller Panels hero banner — reuse the existing Branding & Banners system:
     1) routes/admin.js   — add a 'resellers' slot to BANNER_SLOTS (admin upload UI + validation)
     2) routes/pages.js   — load bannerMap in the /resellers route and pass it to the view
   The public page (views/resellers.ejs) renders bannerMap['resellers'] with the same .hero markup.
   Single-line anchors, guarded + idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_resellers_hero.js <ROOT>'); process.exit(1); }

function sub(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name + ' in ' + file);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name + ' in ' + file);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

/* 1) admin.js — add the resellers banner slot */
sub(path.join(ROOT, 'routes/admin.js'), 'admin:slot', "slug: 'resellers'",
  "{ slug: 'players', name: 'Player activation' }",
  "{ slug: 'players', name: 'Player activation' },\n    { slug: 'resellers', name: 'Reseller Panels' }");

/* 2) pages.js — load bannerMap in the /resellers route */
sub(path.join(ROOT, 'routes/pages.js'), 'pages:bannermap', 'bannerMap: _bmap',
  "res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName, panels: _panels }, s));",
  "let _bmap={}; try{ _bmap=await storefront.loadBannerMap(pool); }catch(e){ _bmap={}; }\n      res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName, panels: _panels, bannerMap: _bmap }, s));");

console.log('RESELLERS HERO PATCH OK');
