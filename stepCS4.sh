#!/usr/bin/env bash
# CS-4: dynamic sitemap.xml + robots.txt (SEO infra).
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== CS-4: sitemap.xml + robots.txt =="

# 1) new route file
cp -f "$SRC/sitemap.js" "$GSZ/routes/sitemap.js"
node --check "$GSZ/routes/sitemap.js"

# 2) patch server.js (backup + restore-on-fail)
cp -f "$GSZ/server.js" "$GSZ/server.js.bak.$TS"
restore(){ echo "!! validation failed — restoring server.js"; cp -f "$GSZ/server.js.bak.$TS" "$GSZ/server.js"; }
trap restore ERR
node "$SRC/patch_cs4.js" "$GSZ"
node --check "$GSZ/server.js"
trap - ERR

# 3) restart + health poll both endpoints
cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
smap=""; rob=""
for i in $(seq 1 25); do
  smap=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/sitemap.xml || true)
  rob=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/robots.txt || true)
  [ "$smap" = "200" ] && [ "$rob" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "sitemap.xml: $smap   robots.txt: $rob"
echo "--- sitemap url count ---"
curl -s http://127.0.0.1:3900/sitemap.xml | grep -c "<loc>" || true
echo "--- robots.txt ---"
curl -s http://127.0.0.1:3900/robots.txt
echo "== CS-4 done =="
