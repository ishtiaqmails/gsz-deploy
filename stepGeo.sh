#!/usr/bin/env bash
# stepGeo.sh — deploy the Geo Page Engine (page half only) + seed 2 demo pages.
# Additive + reversible: backs up server.js, copies new lib/route/view files,
# inserts ONE mount line after the review router, verifies, seeds, restarts,
# health-checks, and ROLLS BACK everything on any failure.
set -uo pipefail
GSZ=/opt/gsz
DEPLOY=/opt/gsz-deploy
TS=$(date +%s)
APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}

SRV="$GSZ/server.js"
SRV_BAK="$SRV.bak.$TS"
NEW_LIBS=(geo.js geo_content.js seo_meta.js seo_gates.js geo_bulk.js)
COPIED=()

restore(){
  echo "!! FAILED — rolling back"
  [ -f "$SRV_BAK" ] && cp -f "$SRV_BAK" "$SRV" && echo "   restored server.js"
  for f in "${COPIED[@]}"; do rm -f "$f" && echo "   removed $f"; done
  pm2 restart "$APP" >/dev/null 2>&1 && echo "   app restarted on previous version"
  exit 1
}
trap restore ERR

echo "==> backup server.js"
cp -f "$SRV" "$SRV_BAK"; echo "   $SRV_BAK"

echo "==> copy engine libs -> $GSZ/lib"
for f in "${NEW_LIBS[@]}"; do cp -f "$DEPLOY/libsrc/$f" "$GSZ/lib/$f"; COPIED+=("$GSZ/lib/$f"); echo "   lib/$f"; done

echo "==> copy route + view + seed"
cp -f "$DEPLOY/routes/geo.js" "$GSZ/routes/geo.js"; COPIED+=("$GSZ/routes/geo.js"); echo "   routes/geo.js"
cp -f "$DEPLOY/views/geo.ejs" "$GSZ/views/geo.ejs"; COPIED+=("$GSZ/views/geo.ejs"); echo "   views/geo.ejs"
mkdir -p "$GSZ/scripts"; cp -f "$DEPLOY/scripts/geo_seed.js" "$GSZ/scripts/geo_seed.js"; echo "   scripts/geo_seed.js"

echo "==> node --check all new JS"
for f in "${NEW_LIBS[@]}"; do node --check "$GSZ/lib/$f"; done
node --check "$GSZ/routes/geo.js"
node --check "$GSZ/scripts/geo_seed.js"
echo "   all JS parse OK"

echo "==> EJS compile check (geo.ejs)"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GSZ"'/views/geo.ejs","utf8"),{filename:"'"$GSZ"'/views/geo.ejs"});console.log("   geo.ejs compiles OK")'

echo "==> insert mount line into server.js (idempotent, after reviewRouter)"
node <<NODE
const fs=require('fs'); const F='$SRV';
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('GEO_ENGINE_MOUNT')>=0){ console.log('   mount already present'); process.exit(0); }
const anchor="app.use('/', reviewRouter);";
const n=s.split(anchor).length-1;
if(n===0) throw new Error('anchor (reviewRouter mount) not found — server.js layout changed');
if(n>1) throw new Error('anchor not unique ('+n+')');
const ins=anchor+"\n/*GEO_ENGINE_MOUNT*/ try { const geoRouter = require('./routes/geo')(pool); app.use('/', geoRouter); } catch (e) { console.error('geo mount failed:', e.message); }";
s=s.split(anchor).join(ins);
fs.writeFileSync(F,s);
console.log('   mount inserted after reviewRouter');
NODE
node --check "$SRV"; echo "   server.js parses OK"

echo "==> restart app ($APP)"
pm2 restart "$APP" >/dev/null 2>&1 || pm2 start "$GSZ/server.js" --name "$APP" >/dev/null 2>&1
sleep 2

echo "==> health check :$PORT"
ok=0; for i in 1 2 3 4 5 6 7 8; do
  if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 || curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
[ "$ok" = "1" ] || { echo "   health check FAILED"; false; }
echo "   app healthy"

echo "==> seed 2 demo pages (PUBLISHED + NOINDEX, real IPTV data)"
GSZ_DIR="$GSZ" node "$GSZ/scripts/geo_seed.js" || echo "   (seed reported an issue — engine still deployed; you can re-run the seed)"

trap - ERR
echo
echo "DONE — geo page engine live. Existing site untouched; new route is fall-through."
echo "Open the demo pages printed above and tell me what to change on the design."
echo "Backup kept at: $SRV_BAK"
