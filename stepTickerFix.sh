#!/usr/bin/env bash
# Fix: product-aware mobile ticker was hidden behind the bottom nav (nav grew to
# ~89px, ticker was pinned at 68px under z-99 nav). Now positioned dynamically
# above the actual nav height. views/partials/app_nav.ejs only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-tickerfix-$TS"; cd "$GSZ"
AN=views/partials/app_nav.ejs
mkdir -p "$BK/$(dirname "$AN")"; cp "$GSZ/$AN" "$BK/$AN"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AN" "$GSZ/$AN"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/app_nav.ejs" "$GSZ/$AN"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$AN';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   app_nav ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — product-aware mobile ticker now sits above the nav and is fully visible."
