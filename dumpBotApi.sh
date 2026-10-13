#!/usr/bin/env bash
# Read-only: shows botapi.js shape (base/key/req helper, configured, existing retrieve fns) and how
# bot_products gets synced — so Claude can wire OTP/link retrieve + the retrieve-config sync safely.
GSZ=/opt/gsz; cd "$GSZ"
echo "===== lib/botapi.js : exports + req helper + configured + any retrieve fns ====="
grep -nE "function [A-Za-z0-9_]+|module.exports|require\(|GSZ_BOT_API|process.env|async function req|function req|X-API-Key|configured|retrieveOtp|retrieveLink|orderStatus|getProducts" lib/botapi.js 2>/dev/null | head -45
echo
echo "===== where bot_products is synced (upsert) — file + lines ====="
grep -rln "INSERT INTO bot_products\|UPDATE bot_products\|ON CONFLICT (sku)" server.js lib/*.js routes/*.js 2>/dev/null | head
SF=$(grep -rl "INSERT INTO bot_products" server.js lib/*.js routes/*.js 2>/dev/null | head -1)
echo "-- sync file: $SF --"
[ -n "$SF" ] && grep -nE "INSERT INTO bot_products|ON CONFLICT|retrieve|types|needs|plans|getProducts|p\.(sku|name|retrieve)" "$SF" | head -20
echo
echo "===== does bot_products have a retrieve column? ====="
node -e "const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});const{Pool}=require(R+'/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{const c=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='bot_products' ORDER BY ordinal_position\")).rows.map(r=>r.column_name);console.log('columns:',c.join(', '));const n=(await p.query(\"SELECT count(*) FILTER (WHERE retrieve IS NOT NULL) AS with_retrieve, count(*) AS total FROM bot_products\").catch(()=>({rows:[{}]}))).rows[0];console.log('retrieve populated:',JSON.stringify(n));await p.end();})().catch(e=>console.log('db:',e.message));"
