#!/usr/bin/env bash
# Galaxy — Products list A2 (UI) + nav cleanup:
#   - new Products list view: search, category chips, clean table (#/thumb/name/category/status +
#     Edit/Toggle/Delete), drag-reorder kept, 20/page pagination, self-aware bulk download panel
#   - hide "Bot mapping" + "Version names" from the admin nav (now covered by the product model)
# Auto-restores the list view + shell on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
LIST=views/admin/products.ejs; TOP=views/admin/_shell_top.ejs
cp -f "$LIST" "$LIST.bak.$TS"; cp -f "$TOP" "$TOP.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$LIST.bak.$TS" "$LIST"; cp -f "$TOP.bak.$TS" "$TOP"; }
trap restore ERR
cp -f "$SRC/adm_products.ejs" "$LIST"
node "$SRC/patch_navhide.js" "$GSZ"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/';['products.ejs','_shell_top.ejs'].forEach(function(f){ejs.compile(fs.readFileSync(p+f,'utf8'),{filename:p+f});console.log('  ejs ok:',f);});"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — A2: new Products list live (search/filter/pagination/bulk); Bot mapping + Version names hidden from nav."
