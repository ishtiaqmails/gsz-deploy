#!/usr/bin/env bash
# #75 finalize — route the two announcement types to their homes + premium admin.
#   - public/js/app.js: top marquee now shows GENERAL announcements (+ evergreen phrases).
#   - views/partials/app_nav.ejs: bottom phone ticker now shows PRODUCT-AWARE items only,
#     tapping opens the Hub Updates tab.
#   - routes/adminAnnouncements.js: stat counts for the 3 cards.
#   - views/admin/announcements.ejs: premium 3-card admin section (audience = All / Buyers of X).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-ann2-$TS"; cd "$GSZ"
AJ=public/js/app.js; AN=views/partials/app_nav.ejs; AR=routes/adminAnnouncements.js; AV=views/admin/announcements.ejs
for f in "$AJ" "$AN" "$AR" "$AV"; do [ -f "$GSZ/$f" ] || { echo "MISSING: $f"; exit 1; }; mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "$AJ" "$AN" "$AR" "$AV"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_marquee.js" "$GSZ"
cp -f "$SRC/app_nav.ejs" "$GSZ/$AN"
node "$SRC/patch_annadmin.js" "$GSZ"
cp -f "$SRC/adm_announcements.ejs" "$GSZ/$AV"
node --check "$GSZ/$AJ" && echo "   app.js ok"
node --check "$GSZ/$AR" && echo "   adminAnnouncements.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$AN','$AV'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   views ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — general -> top marquee, product-aware -> buyer surfaces, premium admin Announcements (3 cards)."
