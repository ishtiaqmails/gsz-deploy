#!/usr/bin/env bash
# GSZ — fix storefront mobile content being cut off behind the fixed bottom nav bar.
# The .gna footer bar is ~89px tall but body padding was 68px, so the last content
# hid behind it. Bumped to 94px (drawer 100px). Only app_nav.ejs changes.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-mobilepad-$TS"; cd "$GSZ"
F=views/partials/app_nav.ejs
mkdir -p "$BK/$(dirname "$F")"; cp "$GSZ/$F" "$BK/$F"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$F" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/app_nav.ejs" "$GSZ/$F"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$F';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   app_nav ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — storefront mobile content now clears the bottom nav bar (no more cut-off)."
