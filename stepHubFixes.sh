#!/usr/bin/env bash
# Hub fixes: (1) IPTV Renewal when logged out now shows the sign-in screen instead of
# "Couldn't load services right now" (hub_model.ejs); (5) Updates & Offers tile removed
# from Quick Access (app_nav.ejs + customer_tools.ejs).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-hubfix-$TS"; cd "$GSZ"
HM=views/partials/hub_model.ejs; NAV=views/partials/app_nav.ejs; CT=views/partials/customer_tools.ejs
for f in "$HM" "$NAV" "$CT"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "$HM" "$NAV" "$CT"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/hub_model.ejs"      "$GSZ/$HM"
cp -f "$SRC/app_nav.ejs"        "$GSZ/$NAV"
cp -f "$SRC/customer_tools.ejs" "$GSZ/$CT"
node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$NAV','$CT'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('   ejs ok '+f)});"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — logged-out IPTV Renewal shows sign-in; Updates & Offers removed from Quick Access."
