#!/usr/bin/env bash
# dumpTrial.sh — READ ONLY. (1) the recent Mega OTT trial that didn't deliver, (2) whether the
# website delivers GENERICALLY via the bot (future-proof) or has per-product-type hardcoding.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== recent trial_claims (last 6) ====="
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const r=await pool.query("SELECT id,trial_type,status,server_name,bot_ref,duration_hours,(credentials IS NOT NULL AND credentials<>'') AS has_creds,claimed_at,expires_at,metadata FROM trial_claims ORDER BY id DESC LIMIT 6");
  r.rows.forEach(x=>console.log('  '+JSON.stringify(x)));
  console.log('\n  --- bot_products matching mega ---');
  const m=await pool.query("SELECT sku,bot_id,name,delivery_type,is_active,needs,missing,stock,plans,types,retrieve FROM bot_products WHERE name ILIKE '%mega%' OR sku ILIKE '%mega%'");
  m.rows.forEach(x=>console.log('  '+JSON.stringify(x)));
  console.log('\n  --- trial_servers (all) ---');
  const ts=await pool.query("SELECT sku,name,enabled,duration_hours,max_per_customer FROM trial_servers ORDER BY name");
  ts.rows.forEach(x=>console.log('  '+JSON.stringify(x)));
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE

echo
echo "===== botapi.js : the trial + delivery calls (how the bot is asked) ====="
grep -nE "function |generateTrial|deliver|provision|async |path:|'/api|\"/api|method|POST|GET" lib/botapi.js 2>/dev/null | head -40

echo
echo "===== lib/trialpoll.js : how a pending trial becomes delivered ====="
grep -nE "function |status|credentials|active|pending|generateTrial|poll|setInterval|UPDATE trial" lib/trialpoll.js 2>/dev/null | head -25

echo
echo "===== lib/deliver.js : GENERIC bot delivery vs per-type switch? (future-proof check) ====="
grep -nE "delivery_type|switch|case |if *\(.*type|botapi|generateTrial|deliver|iptv|netflix|canva|manual|credential" lib/deliver.js 2>/dev/null | head -40

echo
echo "===== lib/botsync.js : does catalog sync bring ALL products generically? ====="
grep -nE "function |delivery_type|INSERT INTO bot_products|ON CONFLICT|skuOf|for *\(|forEach|/api/products|types|plans" lib/botsync.js 2>/dev/null | head -25
