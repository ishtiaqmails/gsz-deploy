#!/usr/bin/env bash
# step63 — Download buttons (customer-facing, multiple per product, label + URL).
# New product_downloads table + admin editor section + product-page buttons.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step63-$TS
mkdir -p "$BAK/routes" "$BAK/views" "$BAK/views/admin"
cp "$APP/routes/adminCatalog.js" "$BAK/routes/adminCatalog.js"
cp "$APP/routes/products.js" "$BAK/routes/products.js"
cp "$APP/views/admin/product_edit.ejs" "$BAK/views/admin/product_edit.ejs"
cp "$APP/views/product.ejs" "$BAK/views/product.ejs"
restore(){ echo "!! rollback";
  cp "$BAK/routes/adminCatalog.js" "$APP/routes/adminCatalog.js"
  cp "$BAK/routes/products.js" "$APP/routes/products.js"
  cp "$BAK/views/admin/product_edit.ejs" "$APP/views/admin/product_edit.ejs"
  cp "$BAK/views/product.ejs" "$APP/views/product.ejs"
  pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> migration: product_downloads table (owned by the app role, so the app can read it)"
SQL="CREATE TABLE IF NOT EXISTS product_downloads (id serial PRIMARY KEY, product_id integer REFERENCES products(id) ON DELETE CASCADE, label text, url text, sort integer DEFAULT 0);
DO \$do\$ DECLARE r text; BEGIN
  SELECT tableowner INTO r FROM pg_tables WHERE tablename='products';
  IF r IS NOT NULL THEN
    EXECUTE format('ALTER TABLE product_downloads OWNER TO %I', r);
    EXECUTE format('ALTER SEQUENCE product_downloads_id_seq OWNER TO %I', r);
  END IF;
END \$do\$;"
( sudo -u postgres psql -d gsz -c "$SQL" 2>&1 || psql -U gsz_user -d gsz -c "$SQL" 2>&1 ) | tail -4

echo "==> patch files"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // adminCatalog editor(): load downloads + pass to view
  { f:A+'/routes/adminCatalog.js',
    a:"let plans = [], faqs = [];",
    b:"let plans = [], faqs = [], downloads = [];" },
  { f:A+'/routes/adminCatalog.js',
    a:"      faqs = (await pool.query('SELECT q, a FROM product_faqs WHERE product_id=$1 ORDER BY sort,id', [prod.id])).rows;",
    b:"      faqs = (await pool.query('SELECT q, a FROM product_faqs WHERE product_id=$1 ORDER BY sort,id', [prod.id])).rows;\n      downloads = (await pool.query('SELECT label, url FROM product_downloads WHERE product_id=$1 ORDER BY sort,id', [prod.id])).rows;" },
  { f:A+'/routes/adminCatalog.js',
    a:"res.render('admin/product_edit', { prod: prod || null, cats, plans, faqs });",
    b:"res.render('admin/product_edit', { prod: prod || null, cats, plans, faqs, downloads });" },
  // adminCatalog save(): persist downloads
  { f:A+'/routes/adminCatalog.js',
    a:"        await c.query('INSERT INTO product_faqs(product_id,q,a,sort) VALUES($1,$2,$3,$4)', [id, q, a, i]);\n      }\n      await c.query('COMMIT');",
    b:"        await c.query('INSERT INTO product_faqs(product_id,q,a,sort) VALUES($1,$2,$3,$4)', [id, q, a, i]);\n      }\n      await c.query('DELETE FROM product_downloads WHERE product_id=$1', [id]);\n      const dls = arr(b.dl_label), dus = arr(b.dl_url);\n      for (let i = 0; i < dls.length; i++) {\n        const lab = (dls[i] || '').trim(), url = (dus[i] || '').trim(); if (!lab || !url) continue;\n        await c.query('INSERT INTO product_downloads(product_id,label,url,sort) VALUES($1,$2,$3,$4)', [id, lab, url, i]);\n      }\n      await c.query('COMMIT');" },
  // products.js: load downloads + pass
  { f:A+'/routes/products.js',
    a:"      const faqs = (await pool.query(\n        'SELECT q, a FROM product_faqs WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;",
    b:"      const faqs = (await pool.query(\n        'SELECT q, a FROM product_faqs WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;\n      const downloads = (await pool.query('SELECT label, url FROM product_downloads WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;" },
  { f:A+'/routes/products.js',
    a:"        p: prow, plans, faqs, similar, accent, rating, orders, payNames",
    b:"        p: prow, plans, faqs, downloads, similar, accent, rating, orders, payNames" },
  // product_edit.ejs: Downloads editor section before the Save buttons
  { f:A+'/views/admin/product_edit.ejs',
    a:"  <div style=\"display:flex;gap:10px\"><button class=\"btn btn-p\" type=\"submit\">Save product</button><a class=\"btn btn-g\" href=\"/admin/products\">Cancel</a></div>",
    b:"  <div class=\"card\">\n    <h2>Download buttons (optional)</h2>\n    <p class=\"hint\">Customer download buttons shown on the product page — a label and a link (APK, setup guide, etc.).</p>\n    <div id=\"dls\">\n      <% (typeof downloads!=='undefined' && downloads.length ? downloads : []).forEach(function(d){ %>\n        <div class=\"dlrow\" style=\"display:grid;grid-template-columns:1fr 1.4fr 34px;gap:8px;margin-bottom:8px\">\n          <input type=\"text\" name=\"dl_label\" placeholder=\"Label (e.g. Download APK)\" value=\"<%= d.label||'' %>\" style=\"margin:0\">\n          <input type=\"text\" name=\"dl_url\" placeholder=\"https://...\" value=\"<%= d.url||'' %>\" style=\"margin:0\">\n          <button type=\"button\" class=\"btn btn-g\" style=\"padding:6px\" onclick=\"this.closest('.dlrow').remove()\">✕</button>\n        </div>\n      <% }); %>\n    </div>\n    <button type=\"button\" class=\"btn btn-g\" onclick=\"addDl()\">+ Add download</button>\n  </div>\n  <div style=\"display:flex;gap:10px\"><button class=\"btn btn-p\" type=\"submit\">Save product</button><a class=\"btn btn-g\" href=\"/admin/products\">Cancel</a></div>" },
  // product_edit.ejs: addDl() script
  { f:A+'/views/admin/product_edit.ejs',
    a:"  document.getElementById('faqs').appendChild(d);}",
    b:"  document.getElementById('faqs').appendChild(d);}\nfunction addDl(){var d=document.createElement('div');d.className='dlrow';d.style.cssText='display:grid;grid-template-columns:1fr 1.4fr 34px;gap:8px;margin-bottom:8px';\n  d.innerHTML='<input type=\"text\" name=\"dl_label\" placeholder=\"Label (e.g. Download APK)\" style=\"margin:0\"><input type=\"text\" name=\"dl_url\" placeholder=\"https://...\" style=\"margin:0\"><button type=\"button\" class=\"btn btn-g\" style=\"padding:6px\" onclick=\"this.closest(\\'.dlrow\\').remove()\">✕</button>';\n  document.getElementById('dls').appendChild(d);}" },
  // product.ejs: styles
  { f:A+'/views/product.ejs',
    a:"  .prod-note svg{flex:none;margin-top:1px;width:18px;height:18px;color:var(--c,#28d6ff)}",
    b:"  .prod-note svg{flex:none;margin-top:1px;width:18px;height:18px;color:var(--c,#28d6ff)}\n  .dl-box{margin:4px 0 20px}\n  .dl-hd{display:flex;align-items:center;gap:7px;font-size:12.5px;font-weight:700;letter-spacing:.02em;color:var(--muted);text-transform:uppercase;margin-bottom:9px}\n  .dl-btns{display:flex;gap:9px;flex-wrap:wrap}\n  .dl-btn{display:inline-flex;align-items:center;gap:8px;background:var(--surface-2,#161a2c);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line-2);border-radius:11px;padding:11px 15px;font-weight:600;font-size:14px}\n  .dl-btn:hover{box-shadow:inset 0 0 0 1.5px var(--b);color:var(--b);transform:translateY(-1px)}\n  .dl-btn svg{width:17px;height:17px}" },
  // product.ejs: render download buttons after the buyrow
  { f:A+'/views/product.ejs',
    a:"          <svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\" style=\"stroke:#fff\"><path d=\"M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z\"/></svg>Order via WhatsApp</a>\n      </div>",
    b:"          <svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\" style=\"stroke:#fff\"><path d=\"M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z\"/></svg>Order via WhatsApp</a>\n      </div>\n\n      <% if (typeof downloads!=='undefined' && downloads.length) { %>\n      <div class=\"dl-box\">\n        <div class=\"dl-hd\"><svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 3v12m0 0 4-4m-4 4-4-4M5 21h14\"/></svg>Downloads</div>\n        <div class=\"dl-btns\">\n          <% downloads.forEach(function(d){ %><a class=\"dl-btn\" href=\"<%= d.url %>\" target=\"_blank\" rel=\"noopener\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 3v12m0 0 4-4m-4 4-4-4M5 21h14\"/></svg><%= d.label %></a><% }); %>\n        </div>\n      </div>\n      <% } %>" },
];
for(const p of P){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip (already): '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f+' :: '+p.a.slice(0,46)); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> node --check + ejs compile"
node --check "$APP/routes/adminCatalog.js"
node --check "$APP/routes/products.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/admin/product_edit.ejs","views/product.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'
grep -q 'name="dl_url"' "$APP/views/admin/product_edit.ejs" || { echo "!! downloads editor missing"; false; }
grep -q 'product_downloads' "$APP/routes/products.js" || { echo "!! products.js downloads load missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
SLUG=$(grep -oE '/product/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/product/##')
PP=$(curl -s -m 15 "http://127.0.0.1:3900/product/$SLUG" || true)
grep -q 'Add to cart' <<<"$PP" || { echo "!! product page broken"; false; }
if grep -qi 'Product error:' <<<"$PP"; then echo "!! product route threw"; false; fi
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/products || true)
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || { echo "!! admin error $CODE"; false; }
trap - ERR
echo "==> step63 OK — download buttons live. Add them in Admin → Products → Edit. Backup: $BAK"
