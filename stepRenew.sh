#!/usr/bin/env bash
# Renew: popup-checkout endpoints (checkout.js) + in-modal renew UI (customer_tools.ejs).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
cp -f "$GSZ/routes/checkout.js" "$GSZ/routes/checkout.js.bak.$TS"
restore(){ echo "!! failed — restoring checkout.js"; cp -f "$GSZ/routes/checkout.js.bak.$TS" "$GSZ/routes/checkout.js"; }
trap restore ERR
cp -f "$SRC/customer_tools.ejs" "$GSZ/views/partials/customer_tools.ejs"
node "$SRC/patch_renew.js" "$GSZ"
node --check "$GSZ/routes/checkout.js"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/partials/customer_tools.ejs','utf8'),{filename:'$GSZ/views/partials/customer_tools.ejs'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Renew live: in-modal checkout (pay here, no page change) + auto-verify + success."
