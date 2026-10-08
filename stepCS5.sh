#!/usr/bin/env bash
# CS-5: Content Studio ADMIN (dashboard, posts, editor, JSON import, redirects)
# + public draft-preview / auto-scheduled publishing.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== CS-5: Content Studio admin =="

# 1) backups of files we overwrite/patch
cp -f "$GSZ/routes/content.js"            "$GSZ/routes/content.js.bak.$TS"
cp -f "$GSZ/routes/sitemap.js"            "$GSZ/routes/sitemap.js.bak.$TS"
cp -f "$GSZ/views/content_article.ejs"    "$GSZ/views/content_article.ejs.bak.$TS"
cp -f "$GSZ/views/admin/_shell_top.ejs"   "$GSZ/views/admin/_shell_top.ejs.bak.$TS"
cp -f "$GSZ/server.js"                     "$GSZ/server.js.bak.$TS"

restore(){ echo "!! validation failed — restoring"; \
  cp -f "$GSZ/routes/content.js.bak.$TS"          "$GSZ/routes/content.js"; \
  cp -f "$GSZ/routes/sitemap.js.bak.$TS"          "$GSZ/routes/sitemap.js"; \
  cp -f "$GSZ/views/content_article.ejs.bak.$TS"  "$GSZ/views/content_article.ejs"; \
  cp -f "$GSZ/views/admin/_shell_top.ejs.bak.$TS" "$GSZ/views/admin/_shell_top.ejs"; \
  cp -f "$GSZ/server.js.bak.$TS"                  "$GSZ/server.js"; \
  rm -f "$GSZ/routes/csAdmin.js"; }
trap restore ERR

# 2) new router + updated public files
cp -f "$SRC/csAdmin.js"           "$GSZ/routes/csAdmin.js"
cp -f "$SRC/content.js"           "$GSZ/routes/content.js"
cp -f "$SRC/sitemap.js"           "$GSZ/routes/sitemap.js"
cp -f "$SRC/content_article.ejs"  "$GSZ/views/content_article.ejs"

# 3) admin views
for v in cs_dashboard cs_posts cs_edit cs_import cs_redirects; do
  cp -f "$SRC/$v.ejs" "$GSZ/views/admin/$v.ejs"
done

# 4) patch nav + mount
node "$SRC/patch_cs5.js" "$GSZ"

# 5) validate JS
node --check "$GSZ/routes/csAdmin.js"
node --check "$GSZ/routes/content.js"
node --check "$GSZ/routes/sitemap.js"
node --check "$GSZ/server.js"

# 6) validate every EJS template (resolves the include tree too)
NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/";
  const files=["content_article.ejs","admin/cs_dashboard.ejs","admin/cs_posts.ejs","admin/cs_edit.ejs","admin/cs_import.ejs","admin/cs_redirects.ejs","admin/_shell_top.ejs"];
  files.forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
'

trap - ERR

# 7) restart + health
cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
login=""; cs=""; art=""; smap=""
for i in $(seq 1 25); do
  login=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true)
  cs=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/cstudio || true)
  art=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/comparisons/best-iptv-players-2026 || true)
  smap=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/sitemap.xml || true)
  [ "$login" = "200" ] && [ "$art" = "200" ] && [ "$smap" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "admin/login: $login   admin/cstudio: $cs (302=needs login, correct)   article: $art   sitemap: $smap"
echo "== CS-5 done =="
