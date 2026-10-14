#!/usr/bin/env bash
# stepNfTier.sh — make the Netflix per-plan TIER an explicit editable admin setting.
#   1) add product_plans.nf_tier (text, nullable; null = derive from label)
#   2) patch routes/adminNetflix.js (read nf_tier, prefer it over derived, add save route)
#   3) deploy adm_netflix.ejs -> views/admin/netflix.ejs (badge -> Phone/TV/Full dropdown + Set)
#   4) deploy netflixHub.js -> routes/ (customer panel honors the explicit tier)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-nftier-$TS"; cd "$GSZ"
AR=routes/adminNetflix.js; HV=views/admin/netflix.ejs; RT=routes/netflixHub.js
mkdir -p "$BK/routes" "$BK/views/admin"
cp "$GSZ/$AR" "$BK/$AR"; cp "$GSZ/$HV" "$BK/$HV"; cp "$GSZ/$RT" "$BK/$RT"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AR" "$GSZ/$AR"; cp "$BK/$HV" "$GSZ/$HV"; cp "$BK/$RT" "$GSZ/$RT"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> 1) migrate: add product_plans.nf_tier"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ await p.query('ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS nf_tier text'); console.log('   nf_tier column ready'); await p.end(); })().catch(e=>{console.error(e.message);process.exit(1);});
"

echo "==> 2) patch adminNetflix.js (route)"
node "$SRC/patch_nftier.js" "$GSZ"

echo "==> 3/4) deploy templates + hub route"
cp -f "$SRC/adm_netflix.ejs" "$GSZ/$HV"
cp -f "$SRC/netflixHub.js" "$GSZ/$RT"

echo "==> checks"
node --check "$GSZ/$AR" && echo "   adminNetflix.js ok"
node --check "$GSZ/$RT" && echo "   netflixHub.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HV','utf8'),{filename:'$GSZ/$HV'});console.log('   netflix.ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Netflix per-plan Tier is now an editable Phone/TV/Full dropdown in Admin → Netflix"
