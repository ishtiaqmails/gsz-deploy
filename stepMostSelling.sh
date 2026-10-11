#!/usr/bin/env bash
# Galaxy — one-click Most Selling star in each product row (no need to open the model).
# Adds POST /admin/products/:id/most-selling + the clickable star in the list. Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/adminCatalog.js; LIST=views/admin/products.ejs
cp -f "$AC" "$AC.bak.$TS"; cp -f "$LIST" "$LIST.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$LIST.bak.$TS" "$LIST"; }
trap restore ERR
node "$SRC/patch_mostselling.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/adm_products.ejs" "$LIST"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/products.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — one-click Most Selling star added to the products list."
