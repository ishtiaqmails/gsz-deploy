#!/usr/bin/env bash
# dumpGeoReady.sh — read-only. (1) Is GSZ behind Cloudflare (for auto-geo)? (2) Do plans have USD prices?
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) Cloudflare in front? (look for cf-ray / server: cloudflare) ###"
curl -sI https://galaxyzayron.store/ 2>/dev/null | grep -iE "^(cf-ray|server|cf-cache-status):" || echo "  (no CF headers seen from here — may be a resolver bypass, not conclusive)"
echo "--- does server.js trust proxy / read any geo header already? ---"
grep -nE "trust proxy|cf-ipcountry|CF-IPCountry|x-forwarded|geo" "$GSZ/server.js" 2>/dev/null | head || echo "  none"

echo
echo "### B) USD prices set on plans? ###"
node - "$GSZ" <<'NODE' 2>&1 | head -20
const R=process.argv[2]; try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg');const E=process.env;
let pool=E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):((E.DB_HOST||E.DB_NAME)?new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE}):new Pool());
(async()=>{ try{
  const t=(await pool.query("SELECT count(*)::int n, count(*) FILTER (WHERE price_usd IS NOT NULL AND price_usd>0)::int withusd, count(*) FILTER (WHERE price_pkr IS NOT NULL AND price_pkr>0)::int withpkr FROM product_plans")).rows[0];
  console.log('  plans total: '+t.n+' | with USD price: '+t.withusd+' | with PKR price: '+t.withpkr);
  const s=(await pool.query("SELECT pr.name, pp.label, pp.price_pkr, pp.price_usd FROM product_plans pp JOIN products pr ON pr.id=pp.product_id WHERE pr.active AND NOT pr.hidden ORDER BY pp.id DESC LIMIT 6")).rows;
  s.forEach(x=>console.log('   '+x.name+' / '+x.label+'  PKR='+x.price_pkr+'  USD='+(x.price_usd==null?'(none)':x.price_usd)));
}catch(e){console.log('  db err:',e.message);} try{await pool.end();}catch(e){} })();
NODE
echo "== END =="
