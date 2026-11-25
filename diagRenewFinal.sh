#!/usr/bin/env bash
# diagRenewFinal — the real renewal order's content-type columns + the submitOrder payload (does it pass whatsapp?). READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### orders table: content-type-ish columns ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND (column_name LIKE '%type%' OR column_name LIKE '%bot%' OR column_name LIKE '%version%' OR column_name LIKE '%adult%' OR column_name='whatsapp') ORDER BY column_name\").then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -3
echo
echo "### recent renewal orders (bot_type vs renew_line.version vs delivered) ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT order_no, plan_label, bot_type, bot_sku, bot_plan_key, status, left(coalesce(delivered_credentials,''),50) dc, fields->'renew_line'->>'version' rlv, (fields ? 'renew_of') ro, created_at FROM orders WHERE (fields ? 'renew_line' OR fields ? 'renew_of') ORDER BY id DESC LIMIT 6\").then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -8
echo
echo "### submitOrder payload in checkout.js (does it pass whatsapp? compare to renew) ###"
grep -n "botapi.submitOrder(" routes/checkout.js
L=$(grep -n "botapi.submitOrder(" routes/checkout.js | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$L,$((L+16))p" routes/checkout.js
echo DONE
