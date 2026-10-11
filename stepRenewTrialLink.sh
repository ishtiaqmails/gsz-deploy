#!/usr/bin/env bash
# Galaxy — Part 1:
#  • Add Product / Edit Product model gets a "Renewable" toggle (products.renewable),
#    persisted + loaded via the model backend (routes/adminCatalog.js).
#  • Trial delivery WhatsApp message link now opens the Hub (/?tool=trials) instead of
#    the old /account/trials page.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/adminCatalog.js
MODEL=views/admin/product_model.ejs
TP=lib/trialpoll.js
cp -f "$AC" "$AC.bak.$TS"; cp -f "$MODEL" "$MODEL.bak.$TS"; cp -f "$TP" "$TP.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$MODEL.bak.$TS" "$MODEL"; cp -f "$TP.bak.$TS" "$TP"; }
trap restore ERR

node "$SRC/patch_renewmodel.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/adm_product_model.ejs" "$MODEL"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$MODEL','utf8'),{filename:process.cwd()+'/'+'$MODEL'});console.log('  product_model ejs ok');"
cp -f "$SRC/trialpoll.js" "$TP"
node --check "$TP"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Renewable toggle is live in the product model (top, under Most Selling); trial delivery link now opens the Hub."
