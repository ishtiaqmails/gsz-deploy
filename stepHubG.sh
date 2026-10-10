#!/usr/bin/env bash
# Galaxy Hub — Deploy G: in-model Buy Now / Checkout (sheet on mobile/tablet, pop-up on desktop).
# Adds a site-wide checkout model + a "Buy Now" button on product pages. Reuses POST /checkout and
# a new GET /account/tools/buy-info (which reuses checkout's own botMeta/customerFields/availability).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
NAV=views/partials/app_nav.ejs
CM=views/partials/checkout_model.ejs
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')

cp -f routes/checkout.js "routes/checkout.js.bak.$TS"
cp -f "$NAV" "$NAV.bak.$TS"
[ -f "$CM" ] && cp -f "$CM" "$CM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "routes/checkout.js.bak.$TS" routes/checkout.js; cp -f "$NAV.bak.$TS" "$NAV"; [ -f "$CM.bak.$TS" ] && cp -f "$CM.bak.$TS" "$CM"; }
trap restore ERR

node "$SRC/patch_buyinfo.js" "$GSZ"
cp -f "$SRC/checkout_model.ejs" "$CM"     # new site-wide partial (must exist before app_nav renders)
cp -f "$SRC/app_nav.ejs" "$NAV"            # now includes checkout_model
node "$SRC/patch_appnav.js" "$GSZ"

node --check routes/checkout.js
node -e "const ejs=require('ejs'),fs=require('fs');['$CM','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy G: in-model Buy Now / Checkout live (Buy Now on product pages; sheet on mobile/tablet, pop-up on desktop)."
