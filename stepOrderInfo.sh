#!/usr/bin/env bash
# Galaxy — customer order is now self-aware of the plan's delivery_instructions + product_note
# (set on the product page): /account/tools/orders returns them, and the Hub order detail
# shows "Delivery instructions" + the product note under the credentials.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/account.js
HM=views/partials/hub_model.ejs
cp -f "$AC" "$AC.bak.$TS"; cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR
node "$SRC/patch_orderinfo.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — delivery instructions + product note now reach the customer on their delivered order."
