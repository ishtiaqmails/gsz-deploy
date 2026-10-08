#!/usr/bin/env bash
# Fix: dashboard panel rows stretched to 100vh (class collision .main). Rename to .rinfo.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Rowfix: .drow .main -> .drow .rinfo =="
cp -f "$GSZ/views/admin/_shell_top.ejs" "$GSZ/views/admin/_shell_top.ejs.bak.$TS"
cp -f "$GSZ/views/admin/dashboard.ejs"  "$GSZ/views/admin/dashboard.ejs.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/views/admin/_shell_top.ejs.bak.$TS" "$GSZ/views/admin/_shell_top.ejs"; cp -f "$GSZ/views/admin/dashboard.ejs.bak.$TS" "$GSZ/views/admin/dashboard.ejs"; }
trap restore ERR

node "$SRC/patch_rowfix.js" "$GSZ"
cp -f "$SRC/adm_dashboard.ejs" "$GSZ/views/admin/dashboard.ejs"

NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/admin/";
  ["_shell_top.ejs","dashboard.ejs"].forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
'
trap - ERR

cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 25); do
  login=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true)
  [ "$login" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "admin/login: $login"
echo "== rowfix done =="
