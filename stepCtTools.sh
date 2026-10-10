#!/usr/bin/env bash
# Customer Tools pop-up: redeploy dashboard view + add pop-up JSON endpoints. Validate + restart.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
cp -f "$GSZ/routes/account.js" "$GSZ/routes/account.js.bak.$TS"
restore(){ echo "!! failed — restoring account.js"; cp -f "$GSZ/routes/account.js.bak.$TS" "$GSZ/routes/account.js"; }
trap restore ERR

echo "== reinstall dashboard view (Quick Access + pop-up) =="
cp -f "$SRC/acc_dashboard.ejs" "$GSZ/views/account/dashboard.ejs"

echo "== add pop-up endpoints =="
node "$SRC/patch_cttools.js" "$GSZ"
node --check "$GSZ/routes/account.js"

echo "== validate EJS =="
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/account/dashboard.ejs','utf8'),{filename:'$GSZ/views/account/dashboard.ejs'});console.log('  ejs ok dashboard');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done
echo "DONE — reload /account: Quick Access tiles open the Customer Tools pop-up."
