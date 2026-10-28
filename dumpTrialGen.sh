#!/usr/bin/env bash
# dumpTrialGen.sh — read-only. How a trial is generated + how botapi identifies the product.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) trials.js — claim/generate flow (what identifier it passes) ###"
grep -nE "generateTrial|trialStatus|claim|trial_type|\.sku|botapi\.|bot_id|server" "$GSZ/routes/trials.js" | head -30

echo
echo "### B) botapi.js — generateTrial + trialStatus (what it sends to the bot) ###"
awk '/generateTrial|trialStatus/{p=NR} p&&NR>=p&&NR<=p+12{printf "%4d| %s\n",NR,$0}' "$GSZ/lib/botapi.js" | head -60
echo "--- how botapi builds the product identifier generally (sku vs id) ---"
grep -nE "sku|product_id|product=|/trial|req\(|path:|qs|params" "$GSZ/lib/botapi.js" | grep -iE "trial|sku|product" | head -20

echo
echo "### C) trial_servers row identifier for Hexa4K (what the claim will send) ###"
node - "$GSZ" <<'NODE' 2>&1 | head -12
const R=process.argv[2];
try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg'); const E=process.env;
let pool; try{ pool = E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):(E.DB_HOST||E.DB_NAME?new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE}):new Pool()); }catch(e){console.log('pool',e.message);}
(async()=>{ try{
  const ts=await pool.query("SELECT sku,name,enabled FROM trial_servers WHERE sku='155' OR name ILIKE '%hexa%'");
  ts.rows.forEach(r=>console.log('  trial_servers: sku='+r.sku+' name='+r.name+' enabled='+r.enabled));
  const bp=await pool.query("SELECT sku,bot_id,serial FROM bot_products WHERE sku='155' OR name ILIKE '%hexa%'");
  bp.rows.forEach(r=>console.log('  bot_products: sku='+r.sku+' bot_id='+r.bot_id+' serial='+r.serial));
}catch(e){console.log('  db err:',e.message);} try{await pool.end();}catch(e){} })();
NODE
echo "== END =="
