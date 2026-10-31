#!/usr/bin/env bash
# stepGeoFix2.sh — reliable geo pricing in stored content + JSON-LD.
#  - lib/seo_meta.js: skip zero/contact-for-price Offers in JSON-LD.
#  - scripts/geo_seed.js: price amount taken from the product's real base price
#    (same value the cards show); gsz_pricing used only to format.
# Restores the "How much does it cost" FAQ with the true lowest price and fixes
# Offer prices. Additive; backs up + rolls back; retry health check on :PORT.
set -uo pipefail
GSZ=/opt/gsz
DEPLOY=/opt/gsz-deploy
APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s)

BAK="$GSZ/lib/seo_meta.js.bak.$TS"
restore(){ echo "!! failed — rolling back seo_meta.js"; [ -f "$BAK" ] && cp -f "$BAK" "$GSZ/lib/seo_meta.js"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup + update lib/seo_meta.js and scripts/geo_seed.js"
cp -f "$GSZ/lib/seo_meta.js" "$BAK"
cp -f "$DEPLOY/libsrc/seo_meta.js" "$GSZ/lib/seo_meta.js"
cp -f "$DEPLOY/scripts/geo_seed.js" "$GSZ/scripts/geo_seed.js"
node --check "$GSZ/lib/seo_meta.js"
node --check "$GSZ/scripts/geo_seed.js"
echo "   files OK (backup: $BAK)"

echo "==> restart app"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 || curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
[ "$ok" = "1" ] || { echo "   health check FAILED on :$PORT"; false; }
echo "   healthy on :$PORT"

echo "==> regenerate the 2 demo pages (reliable prices)"
GSZ_DIR="$GSZ" node "$GSZ/scripts/geo_seed.js"

trap - ERR
echo; echo "DONE — reload the demo pages: cost FAQ shows the real lowest price, Offer schema is clean."
