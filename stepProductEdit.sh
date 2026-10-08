#!/usr/bin/env bash
# Track A / Step 3b — global mobile compatibility + premium product editor.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Mobile compat + product editor =="
cp -f "$GSZ/views/admin/_shell_top.ejs"     "$GSZ/views/admin/_shell_top.ejs.bak.$TS"
cp -f "$GSZ/views/admin/product_edit.ejs"   "$GSZ/views/admin/product_edit.ejs.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/views/admin/_shell_top.ejs.bak.$TS" "$GSZ/views/admin/_shell_top.ejs"; cp -f "$GSZ/views/admin/product_edit.ejs.bak.$TS" "$GSZ/views/admin/product_edit.ejs"; }
trap restore ERR

node "$SRC/patch_mobile.js" "$GSZ"
cp -f "$SRC/adm_product_edit.ejs" "$GSZ/views/admin/product_edit.ejs"

NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/admin/";
  ["_shell_top.ejs","product_edit.ejs"].forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
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
echo "== product editor + mobile done =="
