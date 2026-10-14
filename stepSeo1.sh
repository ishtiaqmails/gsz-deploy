#!/usr/bin/env bash
# stepSeo1.sh — SEO Batch 1: homepage H1, theme-color, dynamic /llms.txt.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-seo1-$TS"; cd "$GSZ"
ST=views/partials/store_top.ejs; HM=views/home.ejs; SM=routes/sitemap.js
mkdir -p "$BK/views/partials" "$BK/routes"
cp "$GSZ/$ST" "$BK/$ST"; cp "$GSZ/$HM" "$BK/$HM"; cp "$GSZ/$SM" "$BK/$SM"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$ST" "$GSZ/$ST"; cp "$BK/$HM" "$GSZ/$HM"; cp "$BK/$SM" "$GSZ/$SM"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch store_top.ejs + home.ejs + sitemap.js"
node "$SRC/patch_seo1.js" "$GSZ"
node --check "$GSZ/$SM" && echo "   sitemap.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$ST','$GSZ/$HM'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:f});});console.log('   views compile');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   llms.txt check:"; curl -s http://127.0.0.1:3900/llms.txt | head -5
echo "DONE — homepage H1 + theme-color + /llms.txt live."
