#!/usr/bin/env bash
# stepGeoUpdate.sh — refresh the geo engine with the overnight improvements and
# regenerate the 2 demo pages so you can review the better version.
#   - lib/geo_content.js : natural titles + per-intent content + local city context
#   - lib/seo_gates.js   : duplicateMax 85 (legit city pages index; clones still caught)
#   - lib/geo_bulk.js    : (recopy, unchanged)
#   - lib/geo_publish.js : NEW publish engine (used by the admin, coming next)
#   - scripts/*          : updated seed + the new locations loader & bulk runner
#   - data/geo_locations.json : 62 real locations (not loaded yet — see note)
# Additive, backs up + rolls back, retry health check. Does NOT bulk-generate or
# load locations (those are separate, deliberate steps once you approve the look).
set -uo pipefail
GSZ=/opt/gsz
DEPLOY=/opt/gsz-deploy
APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s)

UPD_LIBS=(geo_content.js seo_gates.js geo_bulk.js)
NEW_LIBS=(geo_publish.js)
BAKDIR="$GSZ/.geobak.$TS"; mkdir -p "$BAKDIR"
restore(){ echo "!! failed — rolling back libs"; for f in "${UPD_LIBS[@]}"; do [ -f "$BAKDIR/$f" ] && cp -f "$BAKDIR/$f" "$GSZ/lib/$f"; done; for f in "${NEW_LIBS[@]}"; do rm -f "$GSZ/lib/$f"; done; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup + update libs"
for f in "${UPD_LIBS[@]}"; do cp -f "$GSZ/lib/$f" "$BAKDIR/$f"; cp -f "$DEPLOY/libsrc/$f" "$GSZ/lib/$f"; echo "   updated lib/$f"; done
for f in "${NEW_LIBS[@]}"; do cp -f "$DEPLOY/libsrc/$f" "$GSZ/lib/$f"; echo "   added   lib/$f"; done

echo "==> copy scripts + data"
mkdir -p "$GSZ/scripts" "$GSZ/data"
for f in geo_seed.js geo_locations_load.js geo_bulk_run.js; do cp -f "$DEPLOY/scripts/$f" "$GSZ/scripts/$f"; echo "   scripts/$f"; done
cp -f "$DEPLOY/data/geo_locations.json" "$GSZ/data/geo_locations.json"; echo "   data/geo_locations.json"

echo "==> node --check"
for f in "${UPD_LIBS[@]}" "${NEW_LIBS[@]}"; do node --check "$GSZ/lib/$f"; done
for f in geo_seed.js geo_locations_load.js geo_bulk_run.js; do node --check "$GSZ/scripts/$f"; done
echo "   all parse OK"

echo "==> restart app"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && { ok=1; break; }; curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "   health FAILED on :$PORT"; false; }
echo "   healthy on :$PORT"

echo "==> regenerate the 2 demo pages (improved titles + local context)"
GSZ_DIR="$GSZ" node "$GSZ/scripts/geo_seed.js"

trap - ERR
echo
echo "DONE — reload the 2 demo pages to see the improved version:"
echo "   https://galaxyzayron.store/iptv/pakistan"
echo "   https://galaxyzayron.store/iptv/pakistan/peshawar"
echo
echo "When you're happy with the look, the next (separate) steps are:"
echo "   1) node scripts/geo_locations_load.js      # load the 62 locations"
echo "   2) node scripts/geo_bulk_run.js iptv       # stage DRAFT pages (nothing published)"
echo "Backups: $BAKDIR"
