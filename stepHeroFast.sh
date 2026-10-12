#!/usr/bin/env bash
# Hero fast-load: ~2MB banner PNGs -> resized WebP (~100-150KB), <picture> serves WebP first,
# first slide is high-priority + preloaded. Markup only switches to WebP AFTER every banner
# has one (so the page never points at a missing WebP). File patches roll back on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-herofast-$TS"; cd "$GSZ"
H=views/home.ejs; T=views/partials/store_top.ejs
for f in "$H" "$T"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring views (WebP files, if any, are harmless extras)"; for f in "$H" "$T"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

# ensure sharp is available (one-time; most image apps already have it)
node -e "require('$GSZ/node_modules/sharp')" 2>/dev/null || { echo "installing sharp (one-time)..."; (cd "$GSZ" && npm i sharp >/dev/null 2>&1) || true; }

echo "--- converting banners to webp ---"
node "$SRC/convert_banners_webp.js" "$GSZ" | tee /tmp/gsz_webp.log || true
grep -q WEBP_ALL_OK /tmp/gsz_webp.log || { echo "ABORT: webp conversion incomplete — install sharp (cd $GSZ && npm i sharp) then re-run. Nothing changed."; exit 1; }

node "$SRC/patch_herofast.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$H','$T'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   views ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — hero banners are WebP (first slide preloaded + high priority). Much faster, especially on mobile."
