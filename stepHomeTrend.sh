#!/usr/bin/env bash
# Galaxy — home "Trending products" rail now driven by the ★ Most Selling flag (no migration, no
# fallback: shows only starred products, hides when none). Patches lib/storefront.js + views/home.ejs.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
SF=lib/storefront.js; HV=views/home.ejs
cp -f "$SF" "$SF.bak.$TS"; cp -f "$HV" "$HV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$SF.bak.$TS" "$SF"; cp -f "$HV.bak.$TS" "$HV"; }
trap restore ERR
node "$SRC/patch_hometrend.js" "$GSZ"
node --check "$SF"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/home.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — home 'Trending products' rail now shows your ★ Most Selling products."
