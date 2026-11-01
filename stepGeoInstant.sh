#!/usr/bin/env bash
# stepGeoInstant.sh — make the by-location targeting grid save INSTANTLY on each click
# (no Save button). Adds POST /admin/geo/targeting/set (JSON) and the click-to-save UI.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.geoinstbak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/adminGeo.js"; GT="$GSZ/views/admin/geo_targeting.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/adminGeo.js" ] && cp -f "$BAKDIR/adminGeo.js" "$AC"; [ -f "$BAKDIR/geo_targeting.ejs" ] && cp -f "$BAKDIR/geo_targeting.ejs" "$GT"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$AC" "$BAKDIR/adminGeo.js"; cp -f "$GT" "$BAKDIR/geo_targeting.ejs"
echo "==> deploy"
cp -f "$DEPLOY/routes/adminGeo.js"            "$AC"
cp -f "$DEPLOY/views/admin/geo_targeting.ejs" "$GT"
echo "==> checks"
node --check "$AC"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GT"'","utf8"),{filename:"'"$GT"'"});console.log("   view compiles OK")'
echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — targeting grid now saves on every click. Backups: $BAKDIR"
