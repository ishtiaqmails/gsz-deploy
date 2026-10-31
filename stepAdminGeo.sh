#!/usr/bin/env bash
# stepAdminGeo.sh — ship the Geo SEO admin + fold geo pages into the existing sitemap.
#  - lib/geo_admin.js    : shared engine ops (load locations, generate drafts)
#  - routes/adminGeo.js  : /admin/geo dashboard + publish/unpublish/generate actions
#  - views/admin/geo.ejs : self-contained dark admin page (your design tokens)
#  - patch routes/sitemap.js : add PUBLISHED+INDEX geo pages (no second sitemap)
#  - patch server.js     : mount adminGeo at /admin (idempotent)
# Additive, backs up server.js + sitemap.js, node --check + ejs compile, retry
# health, full rollback on any failure.
set -uo pipefail
GSZ=/opt/gsz
DEPLOY=/opt/gsz-deploy
APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s)

SRV="$GSZ/server.js"; SRV_BAK="$SRV.bak.$TS"
SM="$GSZ/routes/sitemap.js"; SM_BAK="$SM.bak.$TS"
COPIED=()
restore(){
  echo "!! failed — rolling back"
  [ -f "$SRV_BAK" ] && cp -f "$SRV_BAK" "$SRV" && echo "   restored server.js"
  [ -f "$SM_BAK" ] && cp -f "$SM_BAK" "$SM" && echo "   restored sitemap.js"
  for f in "${COPIED[@]}"; do rm -f "$f" && echo "   removed $f"; done
  pm2 restart "$APP" >/dev/null 2>&1
  exit 1
}
trap restore ERR

echo "==> backup server.js + sitemap.js"
cp -f "$SRV" "$SRV_BAK"; cp -f "$SM" "$SM_BAK"

echo "==> copy admin files"
cp -f "$DEPLOY/libsrc/geo_admin.js" "$GSZ/lib/geo_admin.js"; COPIED+=("$GSZ/lib/geo_admin.js"); echo "   lib/geo_admin.js"
cp -f "$DEPLOY/libsrc/geo_publish.js" "$GSZ/lib/geo_publish.js"; echo "   lib/geo_publish.js (refresh)"
cp -f "$DEPLOY/routes/adminGeo.js" "$GSZ/routes/adminGeo.js"; COPIED+=("$GSZ/routes/adminGeo.js"); echo "   routes/adminGeo.js"
mkdir -p "$GSZ/views/admin"; cp -f "$DEPLOY/views/admin/geo.ejs" "$GSZ/views/admin/geo.ejs"; COPIED+=("$GSZ/views/admin/geo.ejs"); echo "   views/admin/geo.ejs"

echo "==> node --check + ejs compile"
node --check "$GSZ/lib/geo_admin.js"; node --check "$GSZ/routes/adminGeo.js"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GSZ"'/views/admin/geo.ejs","utf8"),{filename:"'"$GSZ"'/views/admin/geo.ejs"});console.log("   admin/geo.ejs compiles OK")'

echo "==> patch routes/sitemap.js (add geo pages)"
node <<NODE
const fs=require('fs'); const F='$SM';
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('GEO_PAGES_SITEMAP')>=0){ console.log('   sitemap already patched'); process.exit(0); }
const anchor="posts.forEach(function (p) { const pre = TYPE_PREFIX[p.type] || 'blog'; add('/' + pre + '/' + p.slug, iso(p.lm), 'monthly', '0.7'); });";
const n=s.split(anchor).length-1;
if(n!==1) throw new Error('sitemap anchor not unique/found ('+n+')');
const add="\n\n      // 6) geo pages (PUBLISHED + INDEX only) /*GEO_PAGES_SITEMAP*/\n      try { const geop = (await pool.query(\"SELECT slug, COALESCE(published_at,updated_at) lm FROM geo_pages WHERE status='PUBLISHED' AND indexing_status='INDEX' ORDER BY slug\")).rows; geop.forEach(function (g) { add(g.slug, iso(g.lm), 'weekly', '0.6'); }); } catch (e) {}";
s=s.split(anchor).join(anchor+add);
fs.writeFileSync(F,s); console.log('   sitemap.js patched');
NODE
node --check "$SM"

echo "==> mount adminGeo in server.js (idempotent)"
node <<NODE
const fs=require('fs'); const F='$SRV';
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('ADMIN_GEO_MOUNT')>=0){ console.log('   already mounted'); process.exit(0); }
const anchor="app.use('/admin', adminWaitlistRouter);";
const n=s.split(anchor).length-1;
if(n!==1) throw new Error('admin mount anchor not unique/found ('+n+')');
const ins=anchor+"\n/*ADMIN_GEO_MOUNT*/ try { const adminGeoRouter = require('./routes/adminGeo')(pool); app.use('/admin', adminGeoRouter); } catch (e) { console.error('adminGeo mount failed:', e.message); }";
s=s.split(anchor).join(ins);
fs.writeFileSync(F,s); console.log('   mounted after adminWaitlist');
NODE
node --check "$SRV"

echo "==> restart app"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && { ok=1; break; }; curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "   health FAILED on :$PORT"; false; }
echo "   healthy on :$PORT"

trap - ERR
echo
echo "DONE — open the admin:  https://galaxyzayron.store/admin/geo"
echo "There you can: load locations, generate drafts, and publish pages one by one."
echo "Backups: $SRV_BAK , $SM_BAK"
