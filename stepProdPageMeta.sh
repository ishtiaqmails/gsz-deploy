#!/usr/bin/env bash
# Galaxy — product page shows the SELECTED PLAN's availability note + warranty (updates per plan;
# availability falls back to the product note for older products). Also: the model's Warranty field
# is now a figure + unit dropdown (No warranty / Day / Days / … / Lifetime), stored as the same text.
# Patches routes/products.js + views/product.ejs; refreshes the model view. Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
PR=routes/products.js; PV=views/product.ejs; MODEL=views/admin/product_model.ejs
for f in "$PR" "$PV" "$MODEL"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "$PR" "$PV" "$MODEL"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR
node "$SRC/patch_prodpagemeta.js" "$GSZ"
node --check "$PR"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$PV','utf8'),{filename:process.cwd()+'/'+'$PV'});console.log('  product.ejs ok');"
cp -f "$SRC/adm_product_model.ejs" "$MODEL"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/product_model.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  model ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — product page per-plan availability + warranty; model warranty = figure + unit."
