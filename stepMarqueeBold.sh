#!/usr/bin/env bash
# Bold + white top marquee text (match the pill) + asset version bump.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-marqbold-$TS"; cd "$GSZ"
C=public/css/app.css; T=views/partials/store_top.ejs; B=views/partials/store_bottom.ejs
for f in "$C" "$T" "$B"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "$C" "$T" "$B"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_marqueebold.js" "$GSZ"
node "$SRC/patch_assetver.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$T','$B'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   views ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — top marquee text is now bold white; asset version bumped."
