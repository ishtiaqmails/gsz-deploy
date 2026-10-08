#!/usr/bin/env bash
# Track A / Step 2 — premium Orders (list + detail) + shared premium kit in the shell.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Orders premium pass + shared kit =="

for f in views/admin/_shell_top.ejs views/admin/dashboard.ejs views/admin/orders.ejs views/admin/order_detail.ejs routes/adminOrders.js; do
  cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"
done
restore(){ echo "!! failed — restoring"; for f in views/admin/_shell_top.ejs views/admin/dashboard.ejs views/admin/orders.ejs views/admin/order_detail.ejs routes/adminOrders.js; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; }
trap restore ERR

# shared kit into the shell
node "$SRC/patch_kit.js" "$GSZ"

# section files
cp -f "$SRC/adm_dashboard.ejs"     "$GSZ/views/admin/dashboard.ejs"
cp -f "$SRC/adminOrders.js"        "$GSZ/routes/adminOrders.js"
cp -f "$SRC/adm_orders.ejs"        "$GSZ/views/admin/orders.ejs"
cp -f "$SRC/adm_order_detail.ejs"  "$GSZ/views/admin/order_detail.ejs"

# validate
node --check "$GSZ/routes/adminOrders.js"
NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/admin/";
  ["_shell_top.ejs","dashboard.ejs","orders.ejs","order_detail.ejs"].forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
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
echo "== orders done =="
