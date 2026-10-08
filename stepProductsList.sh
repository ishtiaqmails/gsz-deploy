#!/usr/bin/env bash
# Track A / Step 3a — premium Products list (drag-reorder + bulk preserved).
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Products list premium pass =="
cp -f "$GSZ/views/admin/products.ejs" "$GSZ/views/admin/products.ejs.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/views/admin/products.ejs.bak.$TS" "$GSZ/views/admin/products.ejs"; }
trap restore ERR

cp -f "$SRC/adm_products.ejs" "$GSZ/views/admin/products.ejs"
NODE_PATH="$GSZ/node_modules" node -e "require('ejs').compile(require('fs').readFileSync('$GSZ/views/admin/products.ejs','utf8'),{filename:'$GSZ/views/admin/products.ejs'});console.log('ejs ok')"
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
echo "== products list done =="
