#!/usr/bin/env bash
# Galaxy — product page now shows the SELECTED PLAN's product note (set per plan on the
# product page), updating as the customer switches plans — same pattern as the availability
# note + warranty. Patches routes/products.js + views/product.ejs in place.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
PR=routes/products.js
PV=views/product.ejs
cp -f "$PR" "$PR.bak.$TS"; cp -f "$PV" "$PV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$PR.bak.$TS" "$PR"; cp -f "$PV.bak.$TS" "$PV"; }
trap restore ERR
node "$SRC/patch_prodnote.js" "$GSZ"
node --check "$PR"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$PV','utf8'),{filename:process.cwd()+'/'+'$PV'});console.log('  product.ejs ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — product note now shows per selected plan on the product page."
