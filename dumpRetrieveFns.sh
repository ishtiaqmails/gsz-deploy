#!/usr/bin/env bash
# Read-only: the exact gsz-api paths the website calls for OTP/link/subscription, + a couple of
# live retrieve configs (so the spec matches reality and shows if any product has OTP/link enabled).
GSZ=/opt/gsz; cd "$GSZ"
echo "===== botapi retrieveOtp / retrieveLink / getSubscription (exact paths) ====="
sed -n '102,114p' lib/botapi.js
echo
echo "===== sample retrieve configs (3 products) + enabled counts ====="
node -e "const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});const{Pool}=require(R+'/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{const rows=(await p.query(\"SELECT sku,name,retrieve FROM bot_products WHERE retrieve IS NOT NULL ORDER BY sku LIMIT 3\")).rows;rows.forEach(r=>console.log(r.sku,'|',(r.name||'').slice(0,22),'|',JSON.stringify(r.retrieve)));const en=(await p.query(\"SELECT count(*) FILTER (WHERE (retrieve->'otp'->>'enabled')='true') otp, count(*) FILTER (WHERE (retrieve->'link'->>'enabled')='true') link, count(*) FILTER (WHERE (retrieve->'household'->>'enabled')='true') hh FROM bot_products\").catch(()=>({rows:[{}]}))).rows[0];console.log('ENABLED counts:',JSON.stringify(en));await p.end();})().catch(e=>console.log('db:',e.message));"
