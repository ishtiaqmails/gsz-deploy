#!/usr/bin/env bash
# stepReviewsR3.sh — admin product-assign + verified, compact mobile review page, remove Title,
# drop the "checked before it appears" wording.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-reviewsr3-$TS"; cd "$GSZ"
AC=routes/adminCatalog.js; PV=views/product.ejs; RV=views/review.ejs; AR=views/admin/reviews.ejs
mkdir -p "$BK/routes" "$BK/views/admin"
cp "$GSZ/$AC" "$BK/$AC"; cp "$GSZ/$PV" "$BK/$PV"; cp "$GSZ/$RV" "$BK/$RV"; cp "$GSZ/$AR" "$BK/$AR"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AC" "$GSZ/$AC"; cp "$BK/$PV" "$GSZ/$PV"; cp "$BK/$RV" "$GSZ/$RV"; cp "$BK/$AR" "$GSZ/$AR"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install compact review page + admin reviews view; patch adminCatalog + product.ejs"
cp "$SRC/review.ejs" "$GSZ/$RV"
cp "$SRC/admin_reviews.ejs" "$GSZ/$AR"
node "$SRC/patch_reviews_r3.js" "$GSZ"
node --check "$GSZ/$AC" && echo "   adminCatalog.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$RV','$GSZ/$AR','$GSZ/$PV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:f});});console.log('   views compile');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
curl -s -o /dev/null -w '   /review -> %{http_code}\n' http://127.0.0.1:3900/review || true
echo "DONE — compact mobile review page; Title removed; admin has product-assign + verified. Review system complete."
