#!/usr/bin/env bash
# stepGeoPicks.sh — "Pick pages": curated location pages that show only a chosen set of products.
#   * creates table geo_picks
#   * scripts/geo_pick.js            (background generator, reuses content engine + gate)
#   * routes/adminGeo.js             (picks CRUD + spread)
#   * views/admin/geo_picks.ejs      (admin UI)  + geo_targeting.ejs / geo.ejs links
#   * patches routes/geo.js          (PICK_LANDING renders only the pick's products)
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.geopicksbak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/adminGeo.js"; GJ="$GSZ/routes/geo.js"; GT="$GSZ/views/admin/geo_targeting.ejs"; GE="$GSZ/views/admin/geo.ejs"; GP="$GSZ/views/admin/geo_picks.ejs"; SC="$GSZ/scripts/geo_pick.js"
restore(){ echo "!! failed — rolling back";
  [ -f "$BAKDIR/adminGeo.js" ] && cp -f "$BAKDIR/adminGeo.js" "$AC"
  [ -f "$BAKDIR/geo.js" ] && cp -f "$BAKDIR/geo.js" "$GJ"
  [ -f "$BAKDIR/geo_targeting.ejs" ] && cp -f "$BAKDIR/geo_targeting.ejs" "$GT"
  [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GE"
  [ -f "$BAKDIR/geo_picks.ejs" ] && cp -f "$BAKDIR/geo_picks.ejs" "$GP" || rm -f "$GP"
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"
cp -f "$AC" "$BAKDIR/adminGeo.js"; cp -f "$GJ" "$BAKDIR/geo.js"; cp -f "$GT" "$BAKDIR/geo_targeting.ejs"; cp -f "$GE" "$BAKDIR/geo.ejs"
[ -f "$GP" ] && cp -f "$GP" "$BAKDIR/geo_picks.ejs"

echo "==> create table geo_picks"
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  await pool.query(`CREATE TABLE IF NOT EXISTS geo_picks (
    id serial PRIMARY KEY,
    name text NOT NULL,
    slug text NOT NULL UNIQUE,
    category_id integer,
    product_ids integer[] NOT NULL DEFAULT '{}',
    intro text,
    enabled boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  )`);
  console.log('   geo_picks ready');
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE

echo "==> deploy files"
cp -f "$DEPLOY/scripts/geo_pick.js"            "$SC"
cp -f "$DEPLOY/routes/adminGeo.js"             "$AC"
cp -f "$DEPLOY/views/admin/geo_picks.ejs"      "$GP"
cp -f "$DEPLOY/views/admin/geo_targeting.ejs"  "$GT"
cp -f "$DEPLOY/views/admin/geo.ejs"            "$GE"

echo "==> patch routes/geo.js (render pick pages with only their products)"
export GJ
node <<'NODE'
const fs=require('fs'); const GJ=process.env.GJ; let j=fs.readFileSync(GJ,'utf8');
if(j.indexOf("PICK_LANDING")>=0){ console.log('   geo.js already pick-aware'); }
else {
  const anchor="        products = await storefront.loadProducts(pool, page.category_id || null);\n        products = await applyGeoRules(products, page);";
  if(j.split(anchor).length-1!==1) throw new Error('geo.js product-load anchor not unique');
  const neu=
"        if (page.page_type === 'PICK_LANDING' && data.pick && Array.isArray(data.pick.product_ids) && data.pick.product_ids.length) {\n"+
"          const _all = await storefront.loadProducts(pool, null);\n"+
"          const _m = {}; _all.forEach(function (x) { _m[x.id] = x; });\n"+
"          products = data.pick.product_ids.map(function (id) { return _m[id]; }).filter(Boolean);\n"+
"          products = await applyGeoRules(products, page);\n"+
"        } else {\n"+
"          products = await storefront.loadProducts(pool, page.category_id || null);\n"+
"          products = await applyGeoRules(products, page);\n"+
"        }";
  j=j.split(anchor).join(neu);
  fs.writeFileSync(GJ,j); console.log('   geo.js: PICK_LANDING render added');
}
NODE

echo "==> checks"
node --check "$AC"; node --check "$GJ"; node --check "$SC"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");for(const f of ["'"$GP"'","'"$GT"'","'"$GE"'"]){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});}console.log("   views compile OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — open /admin/geo/picks. Backups: $BAKDIR"
