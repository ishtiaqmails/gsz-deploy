#!/usr/bin/env bash
# Galaxy — fix: product-page planRows SELECT now includes avail_note (so per-plan availability loads).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
PR=routes/products.js
cp -f "$PR" "$PR.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$PR.bak.$TS" "$PR"; }
trap restore ERR
node "$SRC/patch_availselect.js" "$GSZ"
node --check "$PR"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — per-plan availability note now loads on the product page."
