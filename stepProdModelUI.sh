#!/usr/bin/env bash
# Galaxy — Product Model, STEP 4 (UI): the Add/Edit Product model (desktop popup + mobile app sheet).
# Replaces the Products list view (Add/Edit now open the model) + adds the model partial. Loads via
# /model.json, saves via /model-save (both shipped in step 3). Old full-page editor left in place as
# a fallback route. Auto-restores both views on any error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
LIST=views/admin/products.ejs
MODEL=views/admin/product_model.ejs
cp -f "$LIST" "$LIST.bak.$TS"
[ -f "$MODEL" ] && cp -f "$MODEL" "$MODEL.bak.$TS" || true
restore(){ echo "!! failed — restoring"; cp -f "$LIST.bak.$TS" "$LIST"; [ -f "$MODEL.bak.$TS" ] && cp -f "$MODEL.bak.$TS" "$MODEL" || rm -f "$MODEL"; }
trap restore ERR
cp -f "$SRC/adm_product_model.ejs" "$MODEL"
cp -f "$SRC/adm_products.ejs" "$LIST"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/';['products.ejs','product_model.ejs'].forEach(function(f){ejs.compile(fs.readFileSync(p+f,'utf8'),{filename:p+f});console.log('  ejs ok:',f);});"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Step 4: Add/Edit Product model live. Open /admin/products and click Add product or Edit."
