#!/usr/bin/env bash
# step68 — Real rating/orders: product page uses the admin rating + real delivered
# "sold" count; homepage review count reflects real approved reviews.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step68-$TS
mkdir -p "$BAK/routes" "$BAK/views"
cp "$APP/routes/products.js" "$BAK/routes/products.js"
cp "$APP/server.js" "$BAK/server.js"
cp "$APP/views/home.ejs" "$BAK/views/home.ejs"
restore(){ echo "!! rollback"; cp "$BAK/routes/products.js" "$APP/routes/products.js"; cp "$BAK/server.js" "$APP/server.js"; cp "$BAK/views/home.ejs" "$APP/views/home.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> patch files"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // products.js: rating from settings, sold = real delivered count
  { f:A+'/routes/products.js',
    a:"      const rating = (4.5 + seeded(prow.id) * 0.5).toFixed(1);\n      const orders = 200 + Math.floor(seeded(prow.id + 7) * 9800);",
    b:"      const rating = settings.rating || '4.9';\n      const orders = (await pool.query(\"SELECT count(*)::int n FROM orders WHERE product_id=$1 AND status='delivered'\", [prow.id])).rows[0].n;" },
  // server.js homeData: count approved reviews
  { f:A+'/server.js',
    a:"  const reviews = (await pool.query(\n    'SELECT author, location, stars, body FROM reviews WHERE approved ORDER BY id DESC LIMIT 6')).rows;",
    b:"  const reviews = (await pool.query(\n    'SELECT author, location, stars, body FROM reviews WHERE approved ORDER BY id DESC LIMIT 6')).rows;\n  const reviewCount = (await pool.query('SELECT count(*)::int n FROM reviews WHERE approved')).rows[0].n;" },
  { f:A+'/server.js',
    a:"heroCats, shellJson };",
    b:"heroCats, shellJson, reviewCount };" },
  // home.ejs: show real approved count when available
  { f:A+'/views/home.ejs',
    a:"<b class=\"tnum\"><%= settings.reviews_count || '1,284' %></b>",
    b:"<b class=\"tnum\"><%= (typeof reviewCount!=='undefined' && reviewCount>0) ? reviewCount.toLocaleString('en-US') : (settings.reviews_count || '1,284') %></b>" },
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
node --check "$APP/routes/products.js"
node --check "$APP/server.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("/opt/gsz/views/home.ejs","utf8"),{filename:"/opt/gsz/views/home.ejs"});console.log("   compiled home.ejs");'

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
SLUG=$(grep -oE '/product/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/product/##')
PP=$(curl -s -m 15 "http://127.0.0.1:3900/product/$SLUG" || true)
grep -q 'Add to cart' <<<"$PP" || { echo "!! product page broken"; false; }
if grep -qi 'Product error:' <<<"$PP"; then echo "!! product route threw"; false; fi
trap - ERR
echo "==> step68 OK — rating/orders now real. Backup: $BAK"
