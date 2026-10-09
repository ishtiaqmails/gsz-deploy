#!/usr/bin/env bash
# Dashboard v2: real logo + real product images. Reinstall views, add image column to queries, restart.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
cp -f "$GSZ/routes/account.js" "$GSZ/routes/account.js.bak.$TS"
restore(){ echo "!! failed — restoring account.js"; cp -f "$GSZ/routes/account.js.bak.$TS" "$GSZ/routes/account.js"; }
trap restore ERR

echo "== reinstall views (logo + product images) =="
cp -f "$SRC/dash_top.ejs"      "$GSZ/views/partials/dash_top.ejs"
cp -f "$SRC/acc_dashboard.ejs" "$GSZ/views/account/dashboard.ejs"
cp -f "$SRC/acc_orders.ejs"    "$GSZ/views/account/orders.ejs"
cp -f "$SRC/acc_products.ejs"  "$GSZ/views/account/products.ejs"

echo "== add image column to queries =="
node "$SRC/patch_accimg.js" "$GSZ"
node --check "$GSZ/routes/account.js"

echo "== validate EJS =="
node -e "const ejs=require('ejs'),fs=require('fs');['views/partials/dash_top.ejs','views/account/dashboard.ejs','views/account/orders.ejs','views/account/products.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  ejs ok '+f);});"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done
echo "DONE — reload /account: real logo + real product photos now."
