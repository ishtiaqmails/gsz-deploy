#!/usr/bin/env bash
# Top marquee -> fully announcement-driven (only posted general announcements; no
# hardcoded fallback) WITH copyable coupon chips; AND product-aware bottom ticker
# gets the same copyable coupon chip. Coupons now copy-on-tap in BOTH places.
# Edits public/js/app.js + public/css/app.css (marquee patch) + views/partials/app_nav.ejs
# (whole-file) + asset version bump.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-marqonly-$TS"; cd "$GSZ"
C=public/js/app.js; S=public/css/app.css; AN=views/partials/app_nav.ejs
T=views/partials/store_top.ejs; B=views/partials/store_bottom.ejs
for f in "$C" "$S" "$AN" "$T" "$B"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "$C" "$S" "$AN" "$T" "$B"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_marqueeonly.js" "$GSZ"
cp -f "$SRC/app_nav.ejs" "$GSZ/$AN"
node --check "$GSZ/$C" && echo "   app.js ok"
node "$SRC/patch_assetver.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$AN','$T','$B'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   views ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — coupons copy-on-tap in top marquee (global) + bottom ticker (product-aware)."
