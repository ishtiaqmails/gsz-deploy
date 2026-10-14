'use strict';
/* SEO Batch 1:
   1) views/partials/store_top.ejs : add <meta name="theme-color">
   2) views/home.ejs               : add a screen-reader <h1> (homepage had none)
   3) routes/sitemap.js            : add a dynamic /llms.txt (AI answer-engine guide)
   Single-line anchors, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_seo1.js <ROOT>'); process.exit(1); }
const ST = path.join(ROOT, 'views/partials/store_top.ejs');
const HM = path.join(ROOT, 'views/home.ejs');
const SM = path.join(ROOT, 'routes/sitemap.js');

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

// 1) theme-color
once(ST, 'seo:theme-color', 'name="theme-color"',
  '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">',
  '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<meta name="theme-color" content="#0b1030">');

// 2) homepage screen-reader H1
once(HM, 'seo:home-h1', 'Buy Premium IPTV, Streaming',
  '<section class="hero">',
  '<h1 style="position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0">Buy Premium IPTV, Streaming &amp; Digital Subscriptions \u2014 Galaxy Subz \u00d7 Zayron</h1>\n<section class="hero">');

// 3) dynamic /llms.txt
const LLMS =
"  router.get('/llms.txt', async function (req, res) {\n" +
"    try {\n" +
"      const b = base(req);\n" +
"      let wa = '923141892712';\n" +
"      try { const _w = (await pool.query(\"SELECT value FROM wa_settings WHERE key='wa_sales_number'\")).rows[0]; if (_w && _w.value) wa = String(_w.value).replace(/[^0-9]/g, ''); } catch (e) {}\n" +
"      const cats = (await pool.query('SELECT name, slug FROM categories WHERE active ORDER BY name')).rows;\n" +
"      const prods = (await pool.query('SELECT name, slug FROM products WHERE active AND NOT hidden ORDER BY name LIMIT 40')).rows;\n" +
"      const LIVE = \"(status='published' OR (status='scheduled' AND scheduled_at IS NOT NULL AND scheduled_at<=now()))\";\n" +
"      const posts = (await pool.query(\"SELECT type, slug, title FROM cs_posts WHERE \" + LIVE + \" ORDER BY COALESCE(updated_at,published_at,created_at) DESC LIMIT 25\")).rows;\n" +
"      const L = [];\n" +
"      L.push('# Galaxy Subz \\u00d7 Zayron'); L.push('');\n" +
"      L.push('> Premium IPTV, streaming accounts and digital subscriptions with instant automated delivery, real WhatsApp support, and free IPTV trials.'); L.push('');\n" +
"      L.push('Galaxy Subz \\u00d7 Zayron (' + b + ') sells premium IPTV services, streaming accounts (Netflix, Disney+, Prime Video and more) and digital subscription products. Orders are delivered instantly and automatically after payment is confirmed. Customers get real human WhatsApp support and can try IPTV servers free before buying.'); L.push('');\n" +
"      if (cats.length) { L.push('## Shop by category'); cats.forEach(function (c) { L.push('- [' + c.name + '](' + b + '/category/' + c.slug + ')'); }); L.push(''); }\n" +
"      if (prods.length) { L.push('## Popular products'); prods.forEach(function (p) { L.push('- [' + p.name + '](' + b + '/product/' + p.slug + ')'); }); L.push(''); }\n" +
"      if (posts.length) { L.push('## Guides & help'); posts.forEach(function (p) { const pre = TYPE_PREFIX[p.type] || 'blog'; L.push('- [' + (p.title || p.slug) + '](' + b + '/' + pre + '/' + p.slug + ')'); }); L.push(''); }\n" +
"      L.push('## Contact & support'); L.push('- Website: ' + b); L.push('- WhatsApp support & sales: https://wa.me/' + wa); L.push('');\n" +
"      L.push('## Key facts'); L.push('- Instant automated delivery after payment'); L.push('- Free IPTV trials (quick WhatsApp verification keeps them fair)'); L.push('- Replacement warranty on eligible products'); L.push('- Full sitemap: ' + b + '/sitemap.xml'); L.push('');\n" +
"      res.set('Cache-Control', 'public, max-age=3600').type('text/plain; charset=utf-8').send(L.join('\\n'));\n" +
"    } catch (e) { res.status(500).type('text/plain').send('llms error: ' + e.message); }\n" +
"  });\n\n  return router;";
once(SM, 'seo:llms', "/llms.txt", "  return router;", LLMS);

console.log('SEO1 PATCH OK');
