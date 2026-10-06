#!/usr/bin/env bash
# step71 — Limited-time products: optional offer end-time + label per product;
# live countdown + badge on the product page (auto-hides when it ends).
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step71-$TS
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

echo "==> migration: products.offer_ends + offer_label"
( sudo -u postgres psql -d gsz -c "ALTER TABLE products ADD COLUMN IF NOT EXISTS offer_ends timestamptz; ALTER TABLE products ADD COLUMN IF NOT EXISTS offer_label text;" 2>&1 \
  || psql -U gsz_user -d gsz -c "ALTER TABLE products ADD COLUMN IF NOT EXISTS offer_ends timestamptz; ALTER TABLE products ADD COLUMN IF NOT EXISTS offer_label text;" 2>&1 ) | tail -1

echo "==> patch files"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // products.js select
  { f:A+'/routes/products.js',
    a:"p.delivery, p.image, p.category_id, p.geo_note, p.note,",
    b:"p.delivery, p.image, p.category_id, p.geo_note, p.note, p.offer_ends, p.offer_label," },
  // adminCatalog save: persist offer fields after downloads, before COMMIT
  { f:A+'/routes/adminCatalog.js',
    a:"        await c.query('INSERT INTO product_downloads(product_id,label,url,sort) VALUES($1,$2,$3,$4)', [id, lab, url, i]);\n      }\n      await c.query('COMMIT');",
    b:"        await c.query('INSERT INTO product_downloads(product_id,label,url,sort) VALUES($1,$2,$3,$4)', [id, lab, url, i]);\n      }\n      await c.query('UPDATE products SET offer_ends=$1, offer_label=$2 WHERE id=$3', [ (b.offer_ends||'').trim()||null, (b.offer_label||'').trim()||null, id ]);\n      await c.query('COMMIT');" },
  // product_edit: offer fields after the note hint
  { f:A+'/views/admin/product_edit.ejs',
    a:"    <p class=\"hint\">A short note shown on the product page (delivery time, device limits, tips). Leave blank for none.</p>",
    b:"    <p class=\"hint\">A short note shown on the product page (delivery time, device limits, tips). Leave blank for none.</p>\n    <label class=\"fld\">Limited-time offer ends at (optional)</label>\n    <input type=\"datetime-local\" name=\"offer_ends\" value=\"<%= (prod && prod.offer_ends) ? new Date(prod.offer_ends).toISOString().slice(0,16) : '' %>\">\n    <label class=\"fld\">Offer label (optional)</label>\n    <input type=\"text\" name=\"offer_label\" value=\"<%= prod ? (prod.offer_label||'') : '' %>\" placeholder=\"e.g. Flash sale\">\n    <p class=\"hint\">Set an end time to show a live countdown + “Limited time” badge on the product page. Leave blank for no offer.</p>" },
  // product.ejs styles
  { f:A+'/views/product.ejs',
    a:"  .dl-btn svg{width:17px;height:17px}",
    b:"  .dl-btn svg{width:17px;height:17px}\n  .lt-offer{display:flex;align-items:center;gap:10px;margin:0 0 18px;flex-wrap:wrap}\n  .lt-badge{display:inline-flex;align-items:center;gap:6px;background:linear-gradient(135deg,#ff5d6c,#ff9a3d);color:#fff;font-weight:800;font-size:12.5px;border-radius:999px;padding:6px 12px}\n  .lt-count{font-family:var(--display);font-weight:800;font-size:15px;color:#ffb3a0;font-variant-numeric:tabular-nums}" },
  // product.ejs display after price
  { f:A+'/views/product.ejs',
    a:"        <span class=\"off\" id=\"pOff\" style=\"display:none\"></span>\n      </div>",
    b:"        <span class=\"off\" id=\"pOff\" style=\"display:none\"></span>\n      </div>\n\n      <% if (p.offer_ends && new Date(p.offer_ends).getTime() > Date.now()) { %>\n      <div class=\"lt-offer\" data-ends=\"<%= new Date(p.offer_ends).toISOString() %>\">\n        <span class=\"lt-badge\">⏳ <%= p.offer_label || 'Limited time' %></span>\n        <span class=\"lt-count\" id=\"ltCount\">—</span>\n      </div>\n      <% } %>" },
  // product.ejs countdown script before bottom include
  { f:A+'/views/product.ejs',
    a:"<%- include('partials/store_bottom') %>",
    b:"<script>\n(function(){var el=document.querySelector('.lt-offer');if(!el)return;var ends=new Date(el.getAttribute('data-ends')).getTime();var out=document.getElementById('ltCount');\nfunction p(n){return(n<10?'0':'')+n;}\nfunction tick(){var d=ends-Date.now();if(d<=0){el.style.display='none';return;}var s=Math.floor(d/1000),dd=Math.floor(s/86400),hh=Math.floor(s%86400/3600),mm=Math.floor(s%3600/60),ss=s%60;if(out)out.textContent=(dd>0?(dd+'d '):'')+p(hh)+':'+p(mm)+':'+p(ss)+' left';setTimeout(tick,1000);}tick();})();\n</script>\n<%- include('partials/store_bottom') %>" },
];
for(const p of P){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip: '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f+' :: '+p.a.slice(0,42)); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> node --check + ejs compile"
node --check "$APP/routes/adminCatalog.js"
node --check "$APP/routes/products.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/admin/product_edit.ejs","views/product.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'
grep -q 'name="offer_ends"' "$APP/views/admin/product_edit.ejs" || { echo "!! offer field missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
SLUG=$(grep -oE '/product/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/product/##')
PP=$(curl -s -m 15 "http://127.0.0.1:3900/product/$SLUG" || true)
grep -q 'Add to cart' <<<"$PP" || { echo "!! product page broken"; false; }
if grep -qi 'Product error:' <<<"$PP"; then echo "!! product route threw"; false; fi
trap - ERR
echo "==> step71 OK — limited-time offers live. Set an offer end in Admin → Products → Edit. Backup: $BAK"
