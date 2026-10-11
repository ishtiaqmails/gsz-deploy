'use strict';
/* Products list rebuild — A1 backend (additive & safe):
   - products list route also returns image, most_selling, cat_slug, and a downloads map (for the
     self-aware bulk download tools)
   - bulk endpoints: /products/bulk-downloads (add/edit/delete/hide/unhide a download across selected)
     and /products/bulk-visibility (hide/unhide/delete selected products)
   - product page hides downloads flagged hidden
   Idempotent. Needs product_downloads.hidden (added by the step's migration). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodlist.js <ROOT>'); process.exit(1); }

/* ---- adminCatalog.js ---- */
(function(){
  const file = path.join(ROOT, 'routes/adminCatalog.js');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;

  // 1) list SELECT: add image, most_selling, cat_slug
  const SEL = "SELECT p.id, p.name, p.slug, p.active, p.hidden, p.trending, c.name AS cat,";
  const SEL2 = "SELECT p.id, p.name, p.slug, p.active, p.hidden, p.trending, p.image, p.most_selling, c.name AS cat, c.slug AS cat_slug,";
  if (s.indexOf("p.image, p.most_selling, c.name AS cat, c.slug AS cat_slug") < 0 && s.indexOf(SEL) >= 0) {
    s = s.replace(SEL, SEL2); ch = true; console.log('adminCatalog A: list SELECT +image/most_selling/cat_slug');
  } else { console.log('adminCatalog A: present or anchor missing (skip)'); }

  // 2) render: build + pass dlmap
  const REN = "    res.render('admin/products', { rows, cats, bots, flash: req.query.ok || null });";
  const REN2 =
    "    const _dl = (await pool.query('SELECT product_id, label, url, COALESCE(hidden,false) AS hidden FROM product_downloads ORDER BY product_id, sort, id')).rows;\n" +
    "    const dlmap = {}; _dl.forEach(function(d){ (dlmap[d.product_id] = dlmap[d.product_id] || []).push({ label: d.label, url: d.url, hidden: d.hidden }); });\n" +
    "    res.render('admin/products', { rows, cats, bots, dlmap, flash: req.query.ok || null });";
  if (s.indexOf('rows, cats, bots, dlmap, flash') < 0 && s.indexOf(REN) >= 0) {
    s = s.replace(REN, REN2); ch = true; console.log('adminCatalog B: dlmap passed to view');
  } else { console.log('adminCatalog B: present or anchor missing (skip)'); }

  // 3) bulk endpoints before the per-product delete route
  const ANCH = "  router.post('/products/:id/delete', auth, async (req, res) => {";
  if (s.indexOf("/products/bulk-downloads") < 0 && s.indexOf(ANCH) >= 0) {
    const NEW = String.raw`  // Bulk download buttons across selected products (self-aware: add/edit/delete/hide/unhide by label)
  router.post('/products/bulk-downloads', auth, jsonBody, async (req, res) => {
    try {
      const b = req.body || {};
      const ids = (Array.isArray(b.ids) ? b.ids : []).map(x => parseInt(x, 10)).filter(Boolean);
      const op = b.op, label = (b.label || '').trim(), url = (b.url || '').trim();
      if (!ids.length) return res.json({ ok: false, error: 'No products selected' });
      if (op === 'add') {
        if (!label || !url) return res.json({ ok: false, error: 'Label and URL required' });
        for (const pid of ids) await pool.query('INSERT INTO product_downloads(product_id,label,url,sort) VALUES($1,$2,$3,COALESCE((SELECT MAX(sort)+1 FROM product_downloads WHERE product_id=$1),0))', [pid, label, url]);
      } else if (op === 'edit') {
        if (!label || !url) return res.json({ ok: false, error: 'Pick a download and a new URL' });
        await pool.query('UPDATE product_downloads SET url=$1 WHERE product_id = ANY($2) AND label=$3', [url, ids, label]);
      } else if (op === 'delete') {
        if (!label) return res.json({ ok: false, error: 'Pick a download' });
        await pool.query('DELETE FROM product_downloads WHERE product_id = ANY($1) AND label=$2', [ids, label]);
      } else if (op === 'hide' || op === 'unhide') {
        if (!label) return res.json({ ok: false, error: 'Pick a download' });
        await pool.query('UPDATE product_downloads SET hidden=$1 WHERE product_id = ANY($2) AND label=$3', [op === 'hide', ids, label]);
      } else return res.json({ ok: false, error: 'Unknown op' });
      res.json({ ok: true });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });
  // Bulk hide/unhide/delete the selected products themselves
  router.post('/products/bulk-visibility', auth, jsonBody, async (req, res) => {
    try {
      const b = req.body || {};
      const ids = (Array.isArray(b.ids) ? b.ids : []).map(x => parseInt(x, 10)).filter(Boolean);
      if (!ids.length) return res.json({ ok: false, error: 'No products selected' });
      if (b.op === 'hide') await pool.query('UPDATE products SET hidden=true WHERE id = ANY($1)', [ids]);
      else if (b.op === 'unhide') await pool.query('UPDATE products SET hidden=false WHERE id = ANY($1)', [ids]);
      else if (b.op === 'delete') await pool.query('DELETE FROM products WHERE id = ANY($1)', [ids]);
      else return res.json({ ok: false, error: 'Unknown op' });
      res.json({ ok: true });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

`;
    s = s.replace(ANCH, NEW + ANCH); ch = true; console.log('adminCatalog C: bulk-downloads + bulk-visibility routes');
  } else { console.log('adminCatalog C: present or anchor missing (skip)'); }

  if (ch) fs.writeFileSync(file, s);
})();

/* ---- routes/products.js : hide hidden downloads on the product page ---- */
(function(){
  const file = path.join(ROOT, 'routes/products.js');
  let s = fs.readFileSync(file, 'utf8');
  const OLD = "SELECT label, url FROM product_downloads WHERE product_id=$1 ORDER BY sort, id";
  const NEW = "SELECT label, url FROM product_downloads WHERE product_id=$1 AND NOT COALESCE(hidden,false) ORDER BY sort, id";
  if (s.indexOf("AND NOT COALESCE(hidden,false) ORDER BY sort, id") >= 0) { console.log('products.js: hidden filter present (skip)'); }
  else if (s.indexOf(OLD) >= 0) { s = s.replace(OLD, NEW); fs.writeFileSync(file, s); console.log('products.js: downloads hidden filter added'); }
  else { console.log('products.js: anchor missing (skip)'); }
})();

console.log('PRODLIST-BACKEND OK');
