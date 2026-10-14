#!/usr/bin/env bash
# stepBing.sh — add the Bing Webmaster verification meta tag to the site head.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-bing-$TS"; cd "$GSZ"
ST=views/partials/store_top.ejs
mkdir -p "$BK/views/partials"; cp "$GSZ/$ST" "$BK/$ST"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$ST" "$GSZ/$ST"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch store_top.ejs (Bing verification meta)"
node "$SRC/patch_bingverify.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$ST','utf8'),{filename:'$GSZ/$ST'});console.log('   store_top.ejs compiles');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   verify tag live:"; curl -s http://127.0.0.1:3900/ | grep -o 'msvalidate.01[^>]*' | head -1
echo "DONE — Bing verification meta tag live. (Then verify in Bing Webmaster.)"
