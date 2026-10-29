#!/usr/bin/env bash
# stepIndexNowAuto.sh — wire auto-IndexNow (boot + daily) into server.js.
#   Submits all indexable URLs (from the live sitemap) to IndexNow so new/changed pages
#   get indexed in minutes. Deploys lib/indexnow_auto.js + patches server.js. Idempotent.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
SV=server.js
cp -f "$SV" "$SV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$SV.bak.$TS" "$GSZ/$SV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/indexnow_auto.js" "$GSZ/lib/indexnow_auto.js"
node --check "$GSZ/lib/indexnow_auto.js" && echo "  indexnow_auto.js ok"
node "$SRC/patch_indexnow_auto.js" "$GSZ"
node --check "$GSZ/$SV" && echo "  server.js ok"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "==> waiting for first IndexNow submit (fires ~15s after boot)..."
sleep 18
pm2 logs gsz --nostream --lines 200 2>/dev/null | grep "\[indexnow\]" | tail -3 || echo "  (log not captured yet — it runs within ~15s, then daily)"
echo "DONE — every indexable page is now auto-submitted to IndexNow on boot and daily."
