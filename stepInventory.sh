#!/usr/bin/env bash
# Track A / Step 4 — premium Inventory (list + stock-manage/add-stock).
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Inventory premium pass =="
cp -f "$GSZ/views/admin/inventory.ejs"         "$GSZ/views/admin/inventory.ejs.bak.$TS"
cp -f "$GSZ/views/admin/inventory_manage.ejs"  "$GSZ/views/admin/inventory_manage.ejs.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/views/admin/inventory.ejs.bak.$TS" "$GSZ/views/admin/inventory.ejs"; cp -f "$GSZ/views/admin/inventory_manage.ejs.bak.$TS" "$GSZ/views/admin/inventory_manage.ejs"; }
trap restore ERR

cp -f "$SRC/adm_inventory.ejs"         "$GSZ/views/admin/inventory.ejs"
cp -f "$SRC/adm_inventory_manage.ejs"  "$GSZ/views/admin/inventory_manage.ejs"

NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/admin/";
  ["inventory.ejs","inventory_manage.ejs"].forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
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
echo "== inventory done =="
