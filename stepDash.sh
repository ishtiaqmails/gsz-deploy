#!/usr/bin/env bash
# Track A / Step 1 — premium command-center dashboard.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Dashboard → command center =="

cp -f "$GSZ/routes/admin.js"            "$GSZ/routes/admin.js.bak.$TS"
cp -f "$GSZ/views/admin/dashboard.ejs"  "$GSZ/views/admin/dashboard.ejs.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/routes/admin.js.bak.$TS" "$GSZ/routes/admin.js"; cp -f "$GSZ/views/admin/dashboard.ejs.bak.$TS" "$GSZ/views/admin/dashboard.ejs"; }
trap restore ERR

# new view + handler patch
cp -f "$SRC/adm_dashboard.ejs" "$GSZ/views/admin/dashboard.ejs"
node "$SRC/patch_dash.js" "$GSZ"

# validate
node --check "$GSZ/routes/admin.js"
NODE_PATH="$GSZ/node_modules" node -e "require('ejs').compile(require('fs').readFileSync('$GSZ/views/admin/dashboard.ejs','utf8'),{filename:'$GSZ/views/admin/dashboard.ejs'});console.log('ejs ok')"

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
echo "== dashboard done =="
