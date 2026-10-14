#!/usr/bin/env bash
# stepReviewsColors.sh — recolor review UI to the dark store theme (page + product-page form).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-reviewscol-$TS"; cd "$GSZ"
PV=views/product.ejs; RV=views/review.ejs
mkdir -p "$BK/views"; cp "$GSZ/$PV" "$BK/$PV"; cp "$GSZ/$RV" "$BK/$RV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$PV" "$GSZ/$PV"; cp "$BK/$RV" "$GSZ/$RV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install dark review page + recolor product review styles"
cp "$SRC/review.ejs" "$GSZ/$RV"
node "$SRC/patch_reviews_colors.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$RV','$GSZ/$PV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:f});});console.log('   both views compile');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
curl -s -o /dev/null -w '   /review -> %{http_code}\n' http://127.0.0.1:3900/review || true
echo "DONE — review page + product review form recolored to the dark theme, responsive."
