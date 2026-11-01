#!/usr/bin/env bash
# stepGoogleIndex.sh — add Google Indexing API alongside the existing IndexNow engine.
#   * lib/google_indexing.js   (JWT -> token -> urlNotifications:publish; no-op until a key is saved)
#   * lib/blog_ping.js         (blogs now also push to Google instantly)
#   * routes/adminGeo.js + views/admin/seo.ejs   (/admin/seo: paste credential, test, run batch)
#   * views/admin/geo.ejs      (link)
#   * patches lib/indexnow_auto.js  (daily sweep also pushes newest URLs to Google, within quota)
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.gidxbak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/adminGeo.js"; BP="$GSZ/lib/blog_ping.js"; GE="$GSZ/views/admin/geo.ejs"; IA="$GSZ/lib/indexnow_auto.js"; GI="$GSZ/lib/google_indexing.js"; SV="$GSZ/views/admin/seo.ejs"
restore(){ echo "!! failed — rolling back";
  [ -f "$BAKDIR/adminGeo.js" ] && cp -f "$BAKDIR/adminGeo.js" "$AC"
  [ -f "$BAKDIR/blog_ping.js" ] && cp -f "$BAKDIR/blog_ping.js" "$BP"
  [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GE"
  [ -f "$BAKDIR/indexnow_auto.js" ] && cp -f "$BAKDIR/indexnow_auto.js" "$IA"
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"
cp -f "$AC" "$BAKDIR/adminGeo.js"; cp -f "$BP" "$BAKDIR/blog_ping.js"; cp -f "$GE" "$BAKDIR/geo.ejs"; cp -f "$IA" "$BAKDIR/indexnow_auto.js"

echo "==> deploy files"
cp -f "$DEPLOY/lib/google_indexing.js"      "$GI"
cp -f "$DEPLOY/lib/blog_ping.js"            "$BP"
cp -f "$DEPLOY/routes/adminGeo.js"          "$AC"
cp -f "$DEPLOY/views/admin/seo.ejs"         "$SV"
cp -f "$DEPLOY/views/admin/geo.ejs"         "$GE"

echo "==> patch lib/indexnow_auto.js (daily Google batch)"
export IA
node <<'NODE'
const fs=require('fs'); const IA=process.env.IA; let s=fs.readFileSync(IA,'utf8');
if(s.indexOf('google_indexing')>=0){ console.log('   already patched'); process.exit(0); }
const anchor="const r = await indexnow.ping(pool, base, urls);";
if(s.split(anchor).length-1!==1) throw new Error('indexnow_auto anchor not unique');
const ins=anchor+"\n      try { const _gi = require('./google_indexing'); const _gr = await _gi.notifyRecent(pool, base, 180); if (_gr && _gr.ok) console.log('[google-indexing] ' + why + ': pushed ' + _gr.submitted + ' URLs' + (_gr.failed?(' ('+_gr.failed+' failed)'):'')); } catch (e) {}";
s=s.split(anchor).join(ins);
fs.writeFileSync(IA,s); console.log('   indexnow_auto.js: daily Google batch added');
NODE

echo "==> checks"
node --check "$GI"; node --check "$BP"; node --check "$AC"; node --check "$IA"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");for(const f of ["'"$SV"'","'"$GE"'"]){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});}console.log("   views compile OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — open /admin/seo to connect Google. Backups: $BAKDIR"
