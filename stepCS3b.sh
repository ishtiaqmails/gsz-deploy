#!/usr/bin/env bash
# CS-3b: redeploy the broken-image-robustness edits + re-import the cleaned sample.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== CS-3b: broken-image robustness + clean sample =="

# 1) back up the three files we overwrite
for f in routes/content.js lib/csrender.js views/content_article.ejs; do
  cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"
done

# 2) copy updated sources into place
cp -f "$SRC/content.js"          "$GSZ/routes/content.js"
cp -f "$SRC/csrender.js"         "$GSZ/lib/csrender.js"
cp -f "$SRC/content_article.ejs" "$GSZ/views/content_article.ejs"

# 3) validate JS + EJS before restart; restore from .bak on any failure
restore(){ echo "!! validation failed — restoring"; \
  cp -f "$GSZ/routes/content.js.bak.$TS" "$GSZ/routes/content.js"; \
  cp -f "$GSZ/lib/csrender.js.bak.$TS" "$GSZ/lib/csrender.js"; \
  cp -f "$GSZ/views/content_article.ejs.bak.$TS" "$GSZ/views/content_article.ejs"; }
trap restore ERR

node --check "$GSZ/routes/content.js"
node --check "$GSZ/lib/csrender.js"
NODE_PATH="$GSZ/node_modules" node -e "require('ejs').compile(require('fs').readFileSync('$GSZ/views/content_article.ejs','utf8'),{filename:'$GSZ/views/content_article.ejs'});console.log('ejs ok')"

# 4) re-import the cleaned sample (idempotent upsert by slug)
cp -f "$SRC/sample.json" "$GSZ/sample.json"
NODE_PATH="$GSZ/node_modules" node "$SRC/import_sample.js" "$GSZ/sample.json"

trap - ERR

# 5) restart + health poll
cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/comparisons/best-iptv-players-2026 || true)
  [ "$code" = "200" ] && { echo "health OK ($code) after ${i}s"; break; }
  sleep 1
done
echo "final: $code"
echo "== CS-3b done =="
