#!/usr/bin/env bash
# #75 Stage 1 — customer announcements surface (premium, product-aware).
#   - routes/account.js: /api/announcements is product-aware when logged in.
#   - views/partials/hub_model.ejs: new "Updates" Hub tab (news/offers cards,
#     coupon copy, product tag) + a "new" dot indicator.
#   - views/partials/customer_tools.ejs + app_nav.ejs: "Updates & Offers" entry
#     on the home band and the mobile sheet.
# Backs up, patches/deploys, validates, restarts, restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-ann-$TS"; cd "$GSZ"
AC=routes/account.js; HM=views/partials/hub_model.ejs; CT=views/partials/customer_tools.ejs; AN=views/partials/app_nav.ejs
for f in "$AC" "$HM" "$CT" "$AN"; do [ -f "$GSZ/$f" ] || { echo "MISSING: $f"; exit 1; }; mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "$AC" "$HM" "$CT" "$AN"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_annfeed.js" "$GSZ"
cp -f "$SRC/hub_model.ejs" "$GSZ/$HM"
cp -f "$SRC/customer_tools.ejs" "$GSZ/$CT"
cp -f "$SRC/app_nav.ejs" "$GSZ/$AN"
node --check "$GSZ/$AC" && echo "   account.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$HM','$CT','$AN'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   partials ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — customers now have a premium, product-aware Updates surface (Hub tab + home + mobile sheet)."
