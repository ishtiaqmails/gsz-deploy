#!/usr/bin/env bash
# stepGeoTgtPolish.sh — cosmetic: drop the duplicate H1 on the targeting page.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
GT="$GSZ/views/admin/geo_targeting.ejs"; TS=$(date +%s)
cp -f "$GT" "$GT.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$GT.xbak.$TS" "$GT"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
cp -f "$DEPLOY/views/admin/geo_targeting.ejs" "$GT"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GT"'","utf8"),{filename:"'"$GT"'"});console.log("   compiles OK")'
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "DONE — duplicate title removed."
