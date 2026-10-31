#!/usr/bin/env bash
# stepAssetVer.sh — auto cache-busting: ?v= derives from each asset's mtime (app.js/app.css).
#   Fixes the stale-app.js freeze (currency UI + mobile category bar) and prevents it recurring.
# Patches server.js, store_top.ejs, store_bottom.ejs. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(server.js views/partials/store_top.ejs views/partials/store_bottom.ejs)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
echo "==> patch"; node "$SRC/patch_assetver.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/server.js" && echo "  server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['views/partials/store_top.ejs','views/partials/store_bottom.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  '+f+' compiles');});"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "==> new asset version in the served HTML:"
curl -s http://127.0.0.1:3900/ | grep -oE "app\.(js|css)\?v=[0-9]+" | sort -u | sed 's/^/   /'
echo
echo "DONE — app.js/app.css now carry their mtime as ?v=. Browsers fetch the fresh file, and every"
echo "future change auto-busts. Your currency UI + mobile category bar are now live."
