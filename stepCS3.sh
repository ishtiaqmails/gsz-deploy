#!/usr/bin/env bash
# stepCS3 — deploy Content Studio public rendering + routes (dark), wire into
# server.js, add optional SEO meta to store_top, and import the sample article.
# All source is committed in /opt/gsz-deploy/libsrc; nothing existing is removed.
set -uo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%Y%m%d-%H%M%S)
cd "$GSZ" || { echo "FATAL: no $GSZ"; exit 1; }

# --- backups of the two files we patch ---
cp -p server.js "server.js.bak-stepCS3-$TS"
cp -p views/partials/store_top.ejs "views/partials/store_top.ejs.bak-stepCS3-$TS"
echo "backups: *.bak-stepCS3-$TS"
restore(){ echo "!! restoring patched files";
  cp -p "server.js.bak-stepCS3-$TS" server.js 2>/dev/null || true
  cp -p "views/partials/store_top.ejs.bak-stepCS3-$TS" views/partials/store_top.ejs 2>/dev/null || true
}
trap 'restore' ERR

# --- copy new files into the app ---
cp "$SRC/csblocks.js" lib/csblocks.js
cp "$SRC/csrender.js" lib/csrender.js
cp "$SRC/content.css" public/css/content.css
cp "$SRC/content.js" routes/content.js
cp "$SRC/content_article.ejs" views/content_article.ejs
cp "$SRC/content_list.ejs" views/content_list.ejs
echo "copied: lib/csblocks.js lib/csrender.js routes/content.js public/css/content.css views/content_article.ejs views/content_list.ejs"

# --- patch server.js + store_top ---
node "$SRC/patch_cs3.js" "$GSZ"

# --- validate JS + EJS ---
node --check lib/csblocks.js && node --check lib/csrender.js && node --check routes/content.js || { echo 'JS CHECK FAIL'; restore; exit 2; }
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['views/content_article.ejs','views/content_list.ejs','views/partials/store_top.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('ejs ok: '+f);});" || { echo 'EJS COMPILE FAIL'; restore; exit 2; }
grep -q "require('./routes/content')" server.js || { echo 'VERIFY FAIL: content router not mounted'; restore; exit 3; }
echo "verify ok: routes wired + views compile"

trap - ERR

# --- import the sample article (published) ---
NODE_PATH="$GSZ/node_modules" node "$SRC/import_sample.js" "$SRC/sample.json" || { echo 'SAMPLE IMPORT FAIL (continuing)'; }

# --- restart + health ---
pm2 restart gsz --update-env >/dev/null 2>&1 || pm2 restart gsz >/dev/null 2>&1
ok=0
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  if [ "$code" = "200" ]; then ok=1; echo "home ok (HTTP 200) after ${i} tries"; break; fi
  sleep 0.6
done
[ "$ok" = "1" ] || { echo "HEALTH FAIL (home last: ${code:-none}) — restoring"; restore; pm2 restart gsz >/dev/null 2>&1; exit 4; }

acode=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:3900/comparisons/best-iptv-players-2026" || true)
hcode=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:3900/blog" || true)
echo "article page: HTTP $acode | /blog hub: HTTP $hcode"
echo "STEPCS3 DONE — Content Studio public rendering is live."
