#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 5: catalog admin
#  RUN: cd /opt/gsz-deploy && git pull && bash step5.sh
#  Adds admin CRUD for products (name, category, descriptions, delivery,
#  plans w/ before-after price, FAQs, show/hide, delete) and categories.
#  Touches ONLY /opt/gsz + pm2 'gsz'. No bot restarts.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP" ] || { echo "ABORT: $APP not found — run earlier steps first."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"
echo "== Galaxy Subz x Zayron — Step 5 (catalog admin) · port $PORT =="
ts=$(date +%s)
cp -a "$APP/server.js" "$APP/server.js.bak-step5.$ts"
cp -a "$APP/views/admin/dashboard.ejs" "$APP/views/admin/dashboard.ejs.bak-step5.$ts"
cp -a "$APP/views/admin/branding.ejs" "$APP/views/admin/branding.ejs.bak-step5.$ts"

# ---------- catalog router ----------
cat > "$APP/routes/adminCatalog.js" <<'GSZ_CAT_EOF'
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  const slugify = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  const arr = v => (v == null ? [] : [].concat(v));

  // ---- products list ----
  router.get('/products', auth, async (req, res) => {
    const rows = (await pool.query(
      `SELECT p.id, p.name, p.slug, p.active, p.hidden, c.name AS cat,
              (SELECT price_pkr FROM product_plans WHERE product_id=p.id ORDER BY sort,id LIMIT 1) AS price
       FROM products p LEFT JOIN categories c ON c.id=p.category_id
       ORDER BY p.sort, p.id`)).rows;
    res.render('admin/products', { rows, flash: req.query.ok || null });
  });

  async function editor(res, prod) {
    const cats = (await pool.query('SELECT id, name FROM categories ORDER BY sort, id')).rows;
    let plans = [], faqs = [];
    if (prod) {
      plans = (await pool.query('SELECT label, price_pkr, old_pkr FROM product_plans WHERE product_id=$1 ORDER BY sort,id', [prod.id])).rows;
      faqs = (await pool.query('SELECT q, a FROM product_faqs WHERE product_id=$1 ORDER BY sort,id', [prod.id])).rows;
    }
    res.render('admin/product_edit', { prod: prod || null, cats, plans, faqs });
  }
  router.get('/products/new', auth, (req, res) => editor(res, null));
  router.get('/products/:id/edit', auth, async (req, res) => {
    const p = (await pool.query('SELECT * FROM products WHERE id=$1', [req.params.id])).rows[0];
    if (!p) return res.redirect('/admin/products?ok=Not+found');
    editor(res, p);
  });

  router.post('/products/save', auth, body, async (req, res) => {
    const c = await pool.connect();
    try {
      await c.query('BEGIN');
      const b = req.body;
      const name = (b.name || '').trim();
      if (!name) throw new Error('Product name is required');
      const category_id = parseInt(b.category_id, 10) || null;
      const short_desc = (b.short_desc || '').trim();
      const long_desc = (b.long_desc || '').trim();
      const delivery = (b.delivery || '').trim();
      const hidden = b.hidden ? true : false;
      let id = parseInt(b.id, 10) || 0;
      if (id) {
        await c.query('UPDATE products SET name=$1,category_id=$2,short_desc=$3,long_desc=$4,delivery=$5,hidden=$6 WHERE id=$7',
          [name, category_id, short_desc, long_desc, delivery, hidden, id]);
      } else {
        const slug = slugify(name) + '-' + Date.now().toString(36);
        const r = await c.query(
          `INSERT INTO products(slug,category_id,name,short_desc,long_desc,delivery,active,hidden,sort)
           VALUES($1,$2,$3,$4,$5,$6,true,$7,COALESCE((SELECT MAX(sort)+1 FROM products),1)) RETURNING id`,
          [slug, category_id, name, short_desc, long_desc, delivery, hidden]);
        id = r.rows[0].id;
      }
      await c.query('DELETE FROM product_plans WHERE product_id=$1', [id]);
      const labels = arr(b.plan_label), prices = arr(b.plan_price), olds = arr(b.plan_old);
      for (let i = 0; i < labels.length; i++) {
        const lab = (labels[i] || '').trim(); if (!lab) continue;
        const price = parseFloat(prices[i]) || 0;
        const old = parseFloat(olds[i]); 
        await c.query('INSERT INTO product_plans(product_id,label,price_pkr,old_pkr,sort) VALUES($1,$2,$3,$4,$5)',
          [id, lab, price, (old && old > 0) ? old : null, i]);
      }
      await c.query('DELETE FROM product_faqs WHERE product_id=$1', [id]);
      const qs = arr(b.faq_q), as = arr(b.faq_a);
      for (let i = 0; i < qs.length; i++) {
        const q = (qs[i] || '').trim(), a = (as[i] || '').trim(); if (!q || !a) continue;
        await c.query('INSERT INTO product_faqs(product_id,q,a,sort) VALUES($1,$2,$3,$4)', [id, q, a, i]);
      }
      await c.query('COMMIT');
      res.redirect('/admin/products?ok=' + encodeURIComponent(name + ' saved'));
    } catch (e) {
      await c.query('ROLLBACK');
      res.status(500).send('Save failed: ' + e.message + ' — <a href="/admin/products">back</a>');
    } finally { c.release(); }
  });

  router.post('/products/:id/toggle', auth, async (req, res) => {
    await pool.query('UPDATE products SET hidden = NOT hidden WHERE id=$1', [req.params.id]);
    res.redirect('/admin/products?ok=Visibility+updated');
  });
  router.post('/products/:id/delete', auth, async (req, res) => {
    try { await pool.query('DELETE FROM products WHERE id=$1', [req.params.id]); res.redirect('/admin/products?ok=Product+deleted'); }
    catch (e) { res.redirect('/admin/products?ok=Delete+failed'); }
  });

  // ---- categories ----
  router.get('/categories', auth, async (req, res) => {
    const rows = (await pool.query(
      `SELECT c.id, c.slug, c.name, c.tag, c.active, c.sort,
              (SELECT count(*) FROM products p WHERE p.category_id=c.id)::int AS n
       FROM categories c ORDER BY c.sort, c.id`)).rows;
    res.render('admin/categories', { rows, flash: req.query.ok || null });
  });
  router.post('/categories/save', auth, body, async (req, res) => {
    const b = req.body; const name = (b.name || '').trim();
    if (!name) return res.redirect('/admin/categories?ok=Name+required');
    const tag = (b.tag || '').trim(); const id = parseInt(b.id, 10) || 0;
    if (id) { await pool.query('UPDATE categories SET name=$1, tag=$2 WHERE id=$3', [name, tag, id]); }
    else {
      const slug = slugify(name);
      await pool.query(
        `INSERT INTO categories(slug,name,tag,glyph,sort) VALUES($1,$2,$3,'tv',COALESCE((SELECT MAX(sort)+1 FROM categories),1))
         ON CONFLICT(slug) DO UPDATE SET name=EXCLUDED.name, tag=EXCLUDED.tag`, [slug, name, tag]);
    }
    res.redirect('/admin/categories?ok=Category+saved');
  });
  router.post('/categories/:id/toggle', auth, async (req, res) => {
    await pool.query('UPDATE categories SET active = NOT active WHERE id=$1', [req.params.id]);
    res.redirect('/admin/categories?ok=Updated');
  });

  return router;
};
GSZ_CAT_EOF
echo "[ok] routes/adminCatalog.js written"

# ---------- products list view ----------
cat > "$APP/views/admin/products.ejs" <<'GSZ_PL_EOF'
<%- include('_layout_top', { siteName: 'Galaxy Subz × Zayron' }) %>
<div class="topbar"><b>Galaxy Subz × Zayron</b><span style="color:var(--muted);font-size:13px">Admin</span><div class="sp"></div>
  <a class="btn btn-g" href="/" target="_blank">View site ↗</a>
  <form method="post" action="/admin/logout" style="display:inline"><button class="btn btn-g" type="submit">Log out</button></form></div>
<div class="wrap">
  <div class="nav"><a href="/admin">Dashboard</a><a href="/admin/branding">Branding &amp; Banners</a><a class="on" href="/admin/products">Products</a><a href="/admin/categories">Categories</a></div>
  <div style="display:flex;align-items:center;gap:14px">
    <div style="flex:1"><h1>Products</h1><p class="sub">Add, edit, show/hide or remove products.</p></div>
    <a class="btn btn-p" href="/admin/products/new">+ Add product</a>
  </div>
  <% if (flash) { %><div class="flash"><%= flash %></div><% } %>
  <div class="card" style="padding:0;overflow:hidden">
    <table style="width:100%;border-collapse:collapse;font-size:14px">
      <thead><tr style="text-align:left;background:#f5f7fc">
        <th style="padding:12px 16px">Product</th><th style="padding:12px 16px">Category</th>
        <th style="padding:12px 16px">From</th><th style="padding:12px 16px">Status</th><th style="padding:12px 16px;text-align:right">Actions</th></tr></thead>
      <tbody>
      <% rows.forEach(function(r){ %>
        <tr style="border-top:1px solid var(--hair)">
          <td style="padding:11px 16px;font-weight:600"><%= r.name %></td>
          <td style="padding:11px 16px;color:var(--muted)"><%= r.cat || '—' %></td>
          <td style="padding:11px 16px">Rs <%= r.price ? Math.round(r.price).toLocaleString('en-US') : '—' %></td>
          <td style="padding:11px 16px"><% if (r.hidden || !r.active) { %><span style="color:#b42318;font-weight:600">Hidden</span><% } else { %><span style="color:#0b7a42;font-weight:600">Live</span><% } %></td>
          <td style="padding:11px 16px;text-align:right;white-space:nowrap">
            <a class="btn btn-g" style="padding:6px 11px" href="/admin/products/<%= r.id %>/edit">Edit</a>
            <form method="post" action="/admin/products/<%= r.id %>/toggle" style="display:inline"><button class="btn btn-g" style="padding:6px 11px" type="submit"><%= (r.hidden||!r.active) ? 'Show' : 'Hide' %></button></form>
            <form method="post" action="/admin/products/<%= r.id %>/delete" style="display:inline" onsubmit="return confirm('Delete this product permanently?')"><button class="btn btn-g" style="padding:6px 11px;color:#b42318" type="submit">Delete</button></form>
          </td>
        </tr>
      <% }); %>
      </tbody>
    </table>
  </div>
</div>
</body></html>
GSZ_PL_EOF

# ---------- product editor view ----------
cat > "$APP/views/admin/product_edit.ejs" <<'GSZ_PE_EOF'
<%- include('_layout_top', { siteName: 'Galaxy Subz × Zayron' }) %>
<div class="topbar"><b>Galaxy Subz × Zayron</b><span style="color:var(--muted);font-size:13px">Admin</span><div class="sp"></div>
  <a class="btn btn-g" href="/admin/products">← Products</a></div>
<div class="wrap" style="max-width:780px">
  <div class="nav"><a href="/admin">Dashboard</a><a href="/admin/branding">Branding &amp; Banners</a><a class="on" href="/admin/products">Products</a><a href="/admin/categories">Categories</a></div>
  <h1><%= prod ? 'Edit product' : 'Add product' %></h1>
  <p class="sub"><%= prod ? prod.name : 'Create a new product in your catalogue.' %></p>
  <form method="post" action="/admin/products/save">
    <% if (prod) { %><input type="hidden" name="id" value="<%= prod.id %>"><% } %>
    <div class="card">
      <label class="fld">Product name</label>
      <input type="text" name="name" value="<%= prod ? prod.name : '' %>" required>
      <label class="fld">Category</label>
      <select name="category_id" style="width:100%;padding:10px 12px;border-radius:9px;border:1px solid var(--hair);font-size:14px;margin-bottom:12px;font-family:inherit">
        <% cats.forEach(function(c){ %><option value="<%= c.id %>" <%= (prod && prod.category_id===c.id)?'selected':'' %>><%= c.name %></option><% }); %>
      </select>
      <label class="fld">Short description (shown on cards)</label>
      <input type="text" name="short_desc" value="<%= prod ? (prod.short_desc||'') : '' %>">
      <label class="fld">Delivery label (e.g. "Instant delivery", "Line in minutes")</label>
      <input type="text" name="delivery" value="<%= prod ? (prod.delivery||'') : '' %>">
      <label class="fld">Long description (shown on the product page)</label>
      <textarea name="long_desc" rows="5" style="width:100%;padding:10px 12px;border-radius:9px;border:1px solid var(--hair);font-size:14px;font-family:inherit;margin-bottom:12px"><%= prod ? (prod.long_desc||'') : '' %></textarea>
      <label style="display:flex;align-items:center;gap:8px;font-size:14px;font-weight:600"><input type="checkbox" name="hidden" <%= (prod && prod.hidden)?'checked':'' %>> Hide this product from the site</label>
    </div>

    <div class="card">
      <h2>Plans &amp; pricing</h2>
      <p class="hint">Each plan has a label, the price (PKR), and an optional "before" price to show a discount.</p>
      <div id="plans">
        <% (plans.length?plans:[{label:'',price_pkr:'',old_pkr:''}]).forEach(function(pl){ %>
          <div class="prow" style="display:grid;grid-template-columns:1fr 120px 120px 34px;gap:8px;margin-bottom:8px">
            <input type="text" name="plan_label" placeholder="e.g. 1 Month" value="<%= pl.label||'' %>">
            <input type="number" step="0.01" name="plan_price" placeholder="Price" value="<%= pl.price_pkr||'' %>">
            <input type="number" step="0.01" name="plan_old" placeholder="Was (opt)" value="<%= pl.old_pkr||'' %>">
            <button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest('.prow').remove()">✕</button>
          </div>
        <% }); %>
      </div>
      <button type="button" class="btn btn-g" onclick="addPlan()">+ Add plan</button>
    </div>

    <div class="card">
      <h2>FAQs (optional)</h2>
      <p class="hint">Shown as an accordion on the product page.</p>
      <div id="faqs">
        <% (faqs.length?faqs:[]).forEach(function(f){ %>
          <div class="frow" style="display:grid;grid-template-columns:1fr 34px;gap:8px;margin-bottom:8px">
            <div style="display:flex;flex-direction:column;gap:6px">
              <input type="text" name="faq_q" placeholder="Question" value="<%= f.q||'' %>">
              <input type="text" name="faq_a" placeholder="Answer" value="<%= f.a||'' %>">
            </div>
            <button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest('.frow').remove()">✕</button>
          </div>
        <% }); %>
      </div>
      <button type="button" class="btn btn-g" onclick="addFaq()">+ Add FAQ</button>
    </div>

    <div style="display:flex;gap:10px;margin-top:4px">
      <button class="btn btn-p" type="submit">Save product</button>
      <a class="btn btn-g" href="/admin/products">Cancel</a>
    </div>
  </form>
</div>
<script>
function addPlan(){var d=document.createElement('div');d.className='prow';d.style.cssText='display:grid;grid-template-columns:1fr 120px 120px 34px;gap:8px;margin-bottom:8px';
  d.innerHTML='<input type="text" name="plan_label" placeholder="e.g. 1 Month"><input type="number" step="0.01" name="plan_price" placeholder="Price"><input type="number" step="0.01" name="plan_old" placeholder="Was (opt)"><button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest(\'.prow\').remove()">✕</button>';
  document.getElementById('plans').appendChild(d);}
function addFaq(){var d=document.createElement('div');d.className='frow';d.style.cssText='display:grid;grid-template-columns:1fr 34px;gap:8px;margin-bottom:8px';
  d.innerHTML='<div style="display:flex;flex-direction:column;gap:6px"><input type="text" name="faq_q" placeholder="Question"><input type="text" name="faq_a" placeholder="Answer"></div><button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest(\'.frow\').remove()">✕</button>';
  document.getElementById('faqs').appendChild(d);}
</script>
</body></html>
GSZ_PE_EOF

# ---------- categories view ----------
cat > "$APP/views/admin/categories.ejs" <<'GSZ_CV_EOF'
<%- include('_layout_top', { siteName: 'Galaxy Subz × Zayron' }) %>
<div class="topbar"><b>Galaxy Subz × Zayron</b><span style="color:var(--muted);font-size:13px">Admin</span><div class="sp"></div>
  <a class="btn btn-g" href="/" target="_blank">View site ↗</a>
  <form method="post" action="/admin/logout" style="display:inline"><button class="btn btn-g" type="submit">Log out</button></form></div>
<div class="wrap" style="max-width:860px">
  <div class="nav"><a href="/admin">Dashboard</a><a href="/admin/branding">Branding &amp; Banners</a><a href="/admin/products">Products</a><a class="on" href="/admin/categories">Categories</a></div>
  <h1>Categories</h1>
  <p class="sub">Your storefront groups products by these categories.</p>
  <% if (flash) { %><div class="flash"><%= flash %></div><% } %>
  <div class="card">
    <h2>Add a category</h2>
    <form method="post" action="/admin/categories/save" style="display:grid;grid-template-columns:1fr 1fr auto;gap:10px;align-items:end">
      <div><label class="fld">Name</label><input type="text" name="name" placeholder="e.g. Music" required style="margin:0"></div>
      <div><label class="fld">Tag (small label)</label><input type="text" name="tag" placeholder="e.g. Streaming" style="margin:0"></div>
      <button class="btn btn-p" type="submit">Add</button>
    </form>
  </div>
  <div class="card" style="padding:0;overflow:hidden">
    <table style="width:100%;border-collapse:collapse;font-size:14px">
      <thead><tr style="text-align:left;background:#f5f7fc"><th style="padding:12px 16px">Category</th><th style="padding:12px 16px">Tag</th><th style="padding:12px 16px">Products</th><th style="padding:12px 16px">Status</th><th style="padding:12px 16px;text-align:right">Actions</th></tr></thead>
      <tbody>
      <% rows.forEach(function(r){ %>
        <tr style="border-top:1px solid var(--hair)">
          <td style="padding:11px 16px;font-weight:600"><%= r.name %></td>
          <td style="padding:11px 16px;color:var(--muted)"><%= r.tag || '—' %></td>
          <td style="padding:11px 16px"><%= r.n %></td>
          <td style="padding:11px 16px"><% if (r.active) { %><span style="color:#0b7a42;font-weight:600">Live</span><% } else { %><span style="color:#b42318;font-weight:600">Hidden</span><% } %></td>
          <td style="padding:11px 16px;text-align:right;white-space:nowrap">
            <form method="post" action="/admin/categories/<%= r.id %>/toggle" style="display:inline"><button class="btn btn-g" style="padding:6px 11px" type="submit"><%= r.active ? 'Hide' : 'Show' %></button></form>
          </td>
        </tr>
      <% }); %>
      </tbody>
    </table>
  </div>
</div>
</body></html>
GSZ_CV_EOF
echo "[ok] admin views written (products, product_edit, categories)"

# ---------- add nav links to existing dashboard + branding ----------
node <<'GSZ_NAV_EOF'
const fs=require('fs');let n=0;
['/opt/gsz/views/admin/dashboard.ejs','/opt/gsz/views/admin/branding.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');
  if(s.includes('/admin/products')){console.log('nav already has products: '+f);return;}
  const a='Branding &amp; Banners</a></div>';
  const b='Branding &amp; Banners</a><a href="/admin/products">Products</a><a href="/admin/categories">Categories</a></div>';
  if(s.includes(a)){s=s.replace(a,b);fs.writeFileSync(f,s);n++;console.log('nav updated: '+f);}
  else{console.log('WARN nav anchor missing: '+f);}
});
console.log('[ok] nav patched: '+n);
GSZ_NAV_EOF

# ---------- dashboard "Catalog" card ----------
node <<'GSZ_DCARD_EOF'
const fs=require('fs');const f='/opt/gsz/views/admin/dashboard.ejs';let s=fs.readFileSync(f,'utf8');
if(!s.includes('Open Products')){
  const anchor='<a class="btn btn-p" href="/admin/branding">Open Branding &amp; Banners</a>\n  </div>';
  const add=anchor+'\n  <div class="card"><h2>Catalog</h2><p class="hint">Add or edit products, plans, pricing, descriptions and FAQs, and manage categories.</p><a class="btn btn-p" href="/admin/products">Open Products</a> <a class="btn btn-g" href="/admin/categories">Categories</a></div>';
  if(s.includes(anchor)){s=s.replace(anchor,add);fs.writeFileSync(f,s);console.log('[ok] dashboard catalog card added');}
  else{console.log('WARN dashboard anchor missing (nav still works)');}
}
GSZ_DCARD_EOF

# ---------- mount catalog router in server.js ----------
node <<'GSZ_MOUNT_EOF'
const fs=require('fs');const f='/opt/gsz/server.js';let s=fs.readFileSync(f,'utf8');
if(s.includes('adminCatalog')){console.log('already mounted');process.exit(0);}
const a="app.use('/admin', adminRouter);";
const b=a+"\nconst adminCatalogRouter = require('./routes/adminCatalog')(pool);\napp.use('/admin', adminCatalogRouter);";
if(!s.includes(a)){console.log('ERROR: admin mount anchor not found');process.exit(1);}
s=s.replace(a,b);fs.writeFileSync(f,s);console.log('[ok] catalog router mounted');
GSZ_MOUNT_EOF

# ---------- validate ----------
node --check "$APP/server.js"
node --check "$APP/routes/adminCatalog.js"
echo "[ok] server.js + adminCatalog.js parse clean"

pm2 restart gsz --update-env >/dev/null
sleep 1.6

LOGIN=$(curl -fsS "http://127.0.0.1:$PORT/admin/login" || true)
HOME=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/admin/products")
if echo "$HOME" | grep -q "window.__DATA" && echo "$LOGIN" | grep -q "Admin sign in" && { [ "$CODE" = "302" ] || [ "$CODE" = "200" ]; }; then
  echo "[ok] site + admin catalog routes live (/admin/products -> HTTP $CODE, gated)"
else
  echo "CHECK FAILED (products route HTTP $CODE) — rolling back"
  cp -a "$APP/server.js.bak-step5.$ts" "$APP/server.js"
  cp -a "$APP/views/admin/dashboard.ejs.bak-step5.$ts" "$APP/views/admin/dashboard.ejs"
  cp -a "$APP/views/admin/branding.ejs.bak-step5.$ts" "$APP/views/admin/branding.ejs"
  pm2 restart gsz >/dev/null; pm2 logs gsz --lines 25 --nostream || true; exit 1
fi

echo "============================================================"
echo " STEP 5 COMPLETE — catalog admin is live"
echo "   admin:  http://143.198.209.68:$PORT/admin/products"
echo "   • Add / edit / show-hide / delete products"
echo "   • Plans with before+after pricing, long description, FAQs"
echo "   • Manage categories"
echo "============================================================"
