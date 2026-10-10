#!/usr/bin/env bash
# Galaxy Hub — Deploy H: checkout polish — remove Transaction ID field, copyable account number,
# currency-aware pay methods (Binance/USDT shown), IPTV versions follow admin labels, single Buy Now
# (hijack native button), and in-model cart "Proceed to checkout". Partials + 2 route patches.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
NAV=views/partials/app_nav.ejs
CM=views/partials/checkout_model.ejs
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')

cp -f routes/account.js "routes/account.js.bak.$TS"
cp -f routes/checkout.js "routes/checkout.js.bak.$TS"
cp -f "$CT" "$CT.bak.$TS"; cp -f "$NAV" "$NAV.bak.$TS"; [ -f "$CM" ] && cp -f "$CM" "$CM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "routes/account.js.bak.$TS" routes/account.js; cp -f "routes/checkout.js.bak.$TS" routes/checkout.js; cp -f "$CT.bak.$TS" "$CT"; cp -f "$NAV.bak.$TS" "$NAV"; [ -f "$CM.bak.$TS" ] && cp -f "$CM.bak.$TS" "$CM"; }
trap restore ERR

node "$SRC/patch_paymethods2.js" "$GSZ"
node "$SRC/patch_buyinfo.js" "$GSZ"
cp -f "$SRC/checkout_model.ejs" "$CM"
cp -f "$SRC/customer_tools.ejs" "$CT"
cp -f "$SRC/app_nav.ejs" "$NAV"
node "$SRC/patch_appnav.js" "$GSZ"

node --check routes/account.js
node --check routes/checkout.js
node -e "const ejs=require('ejs'),fs=require('fs');['$CM','$CT','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy H: no Transaction ID · copyable account · currency-aware pay methods · admin type labels · single Buy Now · in-model cart checkout."
