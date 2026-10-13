#!/usr/bin/env bash
# Add FAQPage structured data to product pages (built from real FAQs), for Google rich results + AI citations.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-faqschema-$TS"; cd "$GSZ"
P=routes/products.js
mkdir -p "$BK/routes"; cp "$GSZ/$P" "$BK/$P"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$P" "$GSZ/$P"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_faqschema.js" "$GSZ"
node --check "$GSZ/$P" && echo "   products.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "--- verify FAQPage schema is on a product page ---"
curl -s https://galaxyzayron.store/product/opplex-tv-iptv 2>/dev/null | grep -o '"@type":"FAQPage"' | head -1 || curl -s http://127.0.0.1:3900/product/opplex-tv-iptv | grep -o '"@type":"FAQPage"' | head -1
echo "(above should print \"@type\":\"FAQPage\" if the schema rendered)"
echo "DONE — product pages now carry Product + FAQPage structured data."
