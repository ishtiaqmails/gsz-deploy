#!/usr/bin/env bash
# stepReviewsR2.sh — customer reviews on the product page (verified buyer form + real reviews +
# aggregateRating star schema from real reviews only).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-reviewsr2-$TS"; cd "$GSZ"
PJ=routes/products.js; PV=views/product.ejs
mkdir -p "$BK/routes" "$BK/views"; cp "$GSZ/$PJ" "$BK/$PJ"; cp "$GSZ/$PV" "$BK/$PV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$PJ" "$GSZ/$PJ"; cp "$BK/$PV" "$GSZ/$PV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch products.js + product.ejs"
node "$SRC/patch_reviews_r2.js" "$GSZ"
node --check "$GSZ/$PJ" && echo "   products.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$PV','utf8'),{filename:'$GSZ/$PV'});console.log('   product.ejs compiles');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   product page check:"; curl -s -o /dev/null -w '   /product/5g-live-zain-tv-iptv -> %{http_code}\n' http://127.0.0.1:3900/product/5g-live-zain-tv-iptv || true
echo "DONE — product pages have the verified-buyer review form + real reviews; star schema from real reviews only."
