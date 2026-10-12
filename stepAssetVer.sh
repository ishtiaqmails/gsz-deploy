#!/usr/bin/env bash
# Bump the /static asset cache-buster (?v=NN) so browsers load freshly-changed
# app.js / app.css, then restart so the view cache picks up the new tag.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-assetver-$TS"; cd "$GSZ"
T=views/partials/store_top.ejs; B=views/partials/store_bottom.ejs
mkdir -p "$BK/$(dirname "$T")"; cp "$GSZ/$T" "$BK/$T"; cp "$GSZ/$B" "$BK/$B"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$T" "$GSZ/$T"; cp "$BK/$B" "$GSZ/$B"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_assetver.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$T','$B'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   views ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — asset version bumped; customers will fetch the updated app.js/app.css."
