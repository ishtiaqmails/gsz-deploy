#!/usr/bin/env bash
# Track A / Batch 1 — Categories, Reviews, Labels, Coupons premium
# + remove awkward intros from Inventory & Products.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Batch 1: categories/reviews/labels/coupons + intro cleanup =="
FILES="categories reviews labels coupons inventory products"
for f in $FILES; do cp -f "$GSZ/views/admin/$f.ejs" "$GSZ/views/admin/$f.ejs.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in $FILES; do cp -f "$GSZ/views/admin/$f.ejs.bak.$TS" "$GSZ/views/admin/$f.ejs"; done; }
trap restore ERR

cp -f "$SRC/adm_categories.ejs" "$GSZ/views/admin/categories.ejs"
cp -f "$SRC/adm_reviews.ejs"    "$GSZ/views/admin/reviews.ejs"
cp -f "$SRC/adm_labels.ejs"     "$GSZ/views/admin/labels.ejs"
cp -f "$SRC/adm_coupons.ejs"    "$GSZ/views/admin/coupons.ejs"
cp -f "$SRC/adm_inventory.ejs"  "$GSZ/views/admin/inventory.ejs"
cp -f "$SRC/adm_products.ejs"   "$GSZ/views/admin/products.ejs"

NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/admin/";
  ["categories.ejs","reviews.ejs","labels.ejs","coupons.ejs","inventory.ejs","products.ejs"].forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
'
trap - ERR

cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
login=""; home=""
for i in $(seq 1 25); do
  login=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true)
  home=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  [ "$login" = "200" ] && [ "$home" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "admin/login: $login   site: $home"
echo "== batch 1 done =="
