#!/usr/bin/env bash
# step61 — Product note (customer-facing): a short note shown on the product page.
# Admin editor field + saved on create/update + product-page display.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step61-$TS
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

echo "==> migration: products.note"
( sudo -u postgres psql -d gsz -c "ALTER TABLE products ADD COLUMN IF NOT EXISTS note text;" 2>&1 \
  || psql -U gsz_user -d gsz -c "ALTER TABLE products ADD COLUMN IF NOT EXISTS note text;" 2>&1 ) | tail -1

echo "==> patch files"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // adminCatalog save: note var + UPDATE + INSERT
  { f:A+'/routes/adminCatalog.js',
    a:"const geo_note = (b.geo_note || '').trim();",
    b:"const geo_note = (b.geo_note || '').trim();\n      const note = (b.note || '').trim();" },
  { f:A+'/routes/adminCatalog.js',
    a:"SET name=$1,category_id=$2,short_desc=$3,long_desc=$4,delivery=$5,geo_note=$6,hidden=$7 WHERE id=$8",
    b:"SET name=$1,category_id=$2,short_desc=$3,long_desc=$4,delivery=$5,geo_note=$6,note=$7,hidden=$8 WHERE id=$9" },
  { f:A+'/routes/adminCatalog.js',
    a:"[name, category_id, short_desc, long_desc, delivery, geo_note, hidden, id]);",
    b:"[name, category_id, short_desc, long_desc, delivery, geo_note, note, hidden, id]);" },
  { f:A+'/routes/adminCatalog.js',
    a:"INSERT INTO products(slug,category_id,name,short_desc,long_desc,delivery,geo_note,active,hidden,sort)",
    b:"INSERT INTO products(slug,category_id,name,short_desc,long_desc,delivery,geo_note,note,active,hidden,sort)" },
  { f:A+'/routes/adminCatalog.js',
    a:"VALUES($1,$2,$3,$4,$5,$6,$7,true,$8,COALESCE((SELECT MAX(sort)+1 FROM products),1)) RETURNING id",
    b:"VALUES($1,$2,$3,$4,$5,$6,$7,$8,true,$9,COALESCE((SELECT MAX(sort)+1 FROM products),1)) RETURNING id" },
  { f:A+'/routes/adminCatalog.js',
    a:"[slug, category_id, name, short_desc, long_desc, delivery, geo_note, hidden]);",
    b:"[slug, category_id, name, short_desc, long_desc, delivery, geo_note, note, hidden]);" },
  // products route: select p.note
  { f:A+'/routes/products.js',
    a:"p.delivery, p.image, p.category_id, p.geo_note,",
    b:"p.delivery, p.image, p.category_id, p.geo_note, p.note," },
  // product_edit: add note field after geo_note hint
  { f:A+'/views/admin/product_edit.ejs',
    a:"    <p class=\"hint\">When set, a clear availability note is shown on the product page so customers in those countries know before they buy.</p>",
    b:"    <p class=\"hint\">When set, a clear availability note is shown on the product page so customers in those countries know before they buy.</p>\n    <label class=\"fld\">Product note (shown on the product page)</label>\n    <input type=\"text\" name=\"note\" value=\"<%= prod ? (prod.note||'') : '' %>\" placeholder=\"e.g. Delivered within 10 minutes · works on 1 device\">\n    <p class=\"hint\">A short note shown on the product page (delivery time, device limits, tips). Leave blank for none.</p>" },
  // product.ejs: style
  { f:A+'/views/product.ejs',
    a:"  .geo-note b{color:#ffd9a0}",
    b:"  .geo-note b{color:#ffd9a0}\n  .prod-note{display:flex;align-items:flex-start;gap:9px;margin:4px 0 16px;padding:12px 14px;border-radius:12px;background:var(--surface);border:1px solid var(--line);color:var(--ink-soft);font-size:13.5px;line-height:1.45}\n  .prod-note svg{flex:none;margin-top:1px;width:18px;height:18px;color:var(--c,#28d6ff)}" },
  // product.ejs: display after geo-note block
  { f:A+'/views/product.ejs',
    a:"        <span><b>Availability note:</b> <%= p.geo_note %></span>\n      </div>\n      <% } %>",
    b:"        <span><b>Availability note:</b> <%= p.geo_note %></span>\n      </div>\n      <% } %>\n\n      <% if (p.note) { %>\n      <div class=\"prod-note\">\n        <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 8h.01M11 12h1v4h1\"/></svg>\n        <span><%= p.note %></span>\n      </div>\n      <% } %>" },
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
grep -q 'name="note"' "$APP/views/admin/product_edit.ejs" || { echo "!! note field missing"; false; }
grep -q 'p.note' "$APP/routes/products.js" || { echo "!! products.js note select missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
SLUG=$(grep -oE '/product/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/product/##')
PP=$(curl -s -m 15 "http://127.0.0.1:3900/product/$SLUG" || true)
grep -q 'Add to cart' <<<"$PP" || { echo "!! product page broken"; false; }
if grep -qi 'Product error:' <<<"$PP"; then echo "!! product route threw"; false; fi
trap - ERR
echo "==> step61 OK — product note live. Set it in Admin → Products → Edit. Backup: $BAK"
