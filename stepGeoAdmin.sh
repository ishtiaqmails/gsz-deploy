#!/usr/bin/env bash
# stepGeoAdmin.sh — premium /admin/geo: search + filters, pagination, bulk publish/unpublish/
# delete (selected or all-matching), per-page. Server-side + indexed queries so it stays fast.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.geoadminbak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/adminGeo.js"; GV="$GSZ/views/admin/geo.ejs"; BP="$GSZ/scripts/geo_bulk_publish.js"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/adminGeo.js" ] && cp -f "$BAKDIR/adminGeo.js" "$AC"; [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GV"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$AC" "$BAKDIR/adminGeo.js"; cp -f "$GV" "$BAKDIR/geo.ejs"

echo "==> deploy"
cp -f "$DEPLOY/routes/adminGeo.js" "$AC"
cp -f "$DEPLOY/views/admin/geo.ejs" "$GV"
cp -f "$DEPLOY/scripts/geo_bulk_publish.js" "$BP"

echo "==> checks"
node --check "$AC"; node --check "$BP"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GV"'","utf8"),{filename:"'"$GV"'"});console.log("   geo.ejs compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — open /admin/geo: filters, pagination, bulk actions. Backups: $BAKDIR"
