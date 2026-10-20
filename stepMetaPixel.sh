#!/usr/bin/env bash
# stepMetaPixel.sh — install Meta Pixel (base PageView on every customer page + Purchase on order confirmation).
# Patches views/partials/store_top.ejs, views/partials/dash_top.ejs, views/order.ejs, views/invoice.ejs,
# views/notfound.ejs. Admin pages are intentionally not tracked. Idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-metapixel-$TS"; cd "$GSZ"
FILES="views/partials/store_top.ejs views/partials/dash_top.ejs views/order.ejs views/invoice.ejs views/notfound.ejs"
mkdir -p "$BK/views/partials"
for f in $FILES; do cp "$GSZ/$f" "$BK/$f"; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in $FILES; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install Meta Pixel"
node "$SRC/patch_metapixel.js" "$GSZ"

echo "==> validate (ejs compile each file)"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');'$FILES'.split(' ').forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   all views compile');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done
echo "==> verify pixel live on homepage"
if curl -s http://127.0.0.1:3900/ | grep -q "fbq('init', '1765880738032271')"; then echo "   PASS: base pixel present on /"; else echo "   WARN: base pixel NOT found on / (check manually)"; fi
echo "==> verify purchase block present in order.ejs source"
grep -q "fb_purchase_" "$GSZ/views/order.ejs" && echo "   PASS: Purchase event wired into order.ejs" || echo "   WARN: Purchase block missing"
echo "DONE — Meta Pixel installed. Base PageView on every customer page; Purchase fires once per paid order on the confirmation page."
