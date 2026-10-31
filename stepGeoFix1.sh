#!/usr/bin/env bash
# stepGeoFix1.sh — ship the "starts from Rs 0" fix + regenerate the demo pages.
# Only touches lib/geo_content.js (additive) and re-runs the idempotent seed
# (ON CONFLICT updates the 2 demo pages' content in place). No restart needed
# for lib changes to take effect on the seed; app already loads the new lib on
# next require — but we restart to be safe since routes/geo.js uses it live.
set -uo pipefail
GSZ=/opt/gsz
DEPLOY=/opt/gsz-deploy
APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s)

BAK="$GSZ/lib/geo_content.js.bak.$TS"
restore(){ echo "!! failed — rolling back geo_content.js"; [ -f "$BAK" ] && cp -f "$BAK" "$GSZ/lib/geo_content.js"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup + update lib/geo_content.js"
cp -f "$GSZ/lib/geo_content.js" "$BAK"
cp -f "$DEPLOY/libsrc/geo_content.js" "$GSZ/lib/geo_content.js"
node --check "$GSZ/lib/geo_content.js"; echo "   geo_content.js OK (backup: $BAK)"

echo "==> restart app"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 || curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 || { echo "health failed"; false; }
echo "   healthy"

echo "==> regenerate the 2 demo pages (fixed pricing copy)"
GSZ_DIR="$GSZ" node "$GSZ/scripts/geo_seed.js"

trap - ERR
echo; echo "DONE — reload the demo pages; the 'start from Rs 0' line is now the real lowest price."
