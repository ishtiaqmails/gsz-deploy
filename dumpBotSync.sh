#!/usr/bin/env bash
# dumpBotSync.sh — read-only. How bot_products gets synced + its current state.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "###### 1) who WRITES bot_products (the sync) ######"
grep -rnE "INSERT INTO bot_products|UPDATE bot_products|ON CONFLICT ?\(sku|DELETE FROM bot_products" "$GSZ"/routes "$GSZ"/lib 2>/dev/null | grep -v node_modules | head -20

echo
echo "###### 2) what TRIGGERS the sync (route / cron / interval) ######"
grep -rnE "bot_products|syncBotProducts|getProducts\(|/sync|setInterval|cron|schedule" "$GSZ"/routes/adminCatalog.js 2>/dev/null | grep -iE "sync|getproducts|bot_products|router\.(get|post)" | head -20
echo "--- server.js / app.js interval or sync wiring ---"
grep -rnE "bot_products|syncBot|getProducts|setInterval|sync" "$GSZ"/server.js "$GSZ"/app.js "$GSZ"/index.js 2>/dev/null | grep -iE "sync|bot_products|getproducts|setInterval" | head -15
echo "--- botapi.js cache TTL + getProducts ---"
grep -nE "function getProducts|cache|TTL|ttl|maxAge|Date.now" "$GSZ/lib/botapi.js" 2>/dev/null | head -12

echo
echo "###### 3) current bot_products rows (newest first) ######"
KEY=$(grep -oE "^(DATABASE_URL|PG_URL|DB_URL|POSTGRES_URL)=" "$GSZ/.env" 2>/dev/null | head -1 | tr -d '=')
node - "$GSZ" "$KEY" <<'NODE' 2>/dev/null || echo "   (db read skipped — connection)"
const R=process.argv[2], K=process.argv[3]||'DATABASE_URL';
require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const {Pool}=require(R+'/node_modules/pg');
const cs=process.env[K]||process.env.DATABASE_URL;
const pool = cs ? new Pool({connectionString:cs}) : new Pool();
(async()=>{
  const c=await pool.query("SELECT count(*)::int n FROM bot_products");
  console.log('   total rows: '+c.rows[0].n);
  const r=await pool.query("SELECT sku,LEFT(COALESCE(name,''),30) nm,COALESCE(is_active,true) active,COALESCE(missing,false) missing,updated_at FROM bot_products ORDER BY updated_at DESC NULLS LAST, sku LIMIT 15");
  r.rows.forEach(x=>console.log('   '+x.sku+' | '+x.nm+' | active='+x.active+' missing='+x.missing+' | '+(x.updated_at?new Date(x.updated_at).toISOString().slice(0,16):'(no ts)')));
  await pool.end();
})().catch(e=>console.error('   db err:',e.message));
NODE
echo "== END =="
