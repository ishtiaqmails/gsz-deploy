#!/usr/bin/env bash
# Redeploy customer-dashboard views only (no DB/route changes). Reusable for view tweaks.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
cp -f "$SRC/dash_top.ejs"      "$GSZ/views/partials/dash_top.ejs"
cp -f "$SRC/dash_bottom.ejs"   "$GSZ/views/partials/dash_bottom.ejs"
cp -f "$SRC/acc_dashboard.ejs" "$GSZ/views/account/dashboard.ejs"
cp -f "$SRC/acc_orders.ejs"    "$GSZ/views/account/orders.ejs"
cp -f "$SRC/acc_products.ejs"  "$GSZ/views/account/products.ejs"
cd "$GSZ"
node -e "const ejs=require('ejs'),fs=require('fs');['views/partials/dash_top.ejs','views/partials/dash_bottom.ejs','views/account/dashboard.ejs','views/account/orders.ejs','views/account/products.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  ejs ok '+f);});"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done
echo "DONE — reload /account."
