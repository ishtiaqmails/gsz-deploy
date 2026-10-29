#!/usr/bin/env bash
# stepSkuRemap.sh — re-point website references from old id-fallback SKUs to the bot's new
#   real SKUs (e.g. Hexa4K 155 -> SKU-00155), matched by immutable bot_id. Syncs first, then
#   remaps product_plans/trial_servers/bot_type_labels, drops orphan rows. Idempotent.
#   Read/writes DB only; restarts gsz at the end to refresh the bot-catalogue cache.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
cd "$GSZ"

echo "==> before:"
node - "$GSZ" <<'NODE' 2>&1 | head -6
const R=process.argv[2]; try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg');const E=process.env;
let pool=E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):((E.DB_HOST||E.DB_NAME)?new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE}):new Pool());
(async()=>{try{const a=await pool.query("SELECT bot_sku,count(*)::int n FROM product_plans WHERE bot_sku IN ('155','SKU-00155') GROUP BY bot_sku");a.rows.forEach(r=>console.log('   product_plans bot_sku='+r.bot_sku+' -> '+r.n+' plan(s)'));const t=await pool.query("SELECT sku,enabled FROM trial_servers WHERE sku IN ('155','SKU-00155')");t.rows.forEach(r=>console.log('   trial_servers sku='+r.sku+' enabled='+r.enabled));}catch(e){console.log('   (pre-check skipped: '+e.message+')');}try{await pool.end();}catch(e){}})();
NODE

echo "==> run remap"
node "$SRC/sku_remap.js" "$GSZ"

echo "==> restart gsz (refresh bot-catalogue cache)"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Hexa4K now mapped to its real SKU. Its trial will generate; everything stays linked."
