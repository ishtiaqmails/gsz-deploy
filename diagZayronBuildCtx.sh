#!/usr/bin/env bash
# diagZayronBuildCtx — the mapping admin UI (467), the full delivery path + message (orderWorker 90-160), and any
# IPTV assumption in checkout/order creation, to enable all product types safely. READ-ONLY.
set +e
cd /opt/zayron 2>/dev/null || { echo "no /opt/zayron"; exit 0; }
echo "########## admin.js: the server->bot-product mapping UI (455-500) ##########"
sed -n '455,500p' routes/admin.js
echo
echo "########## orderWorker.js: delivery + message (90-160) ##########"
sed -n '90,160p' lib/orderWorker.js
echo
echo "########## checkout / order creation: any delivery_type or iptv assumption ##########"
grep -rn "delivery_type\|iptv\|content_type\|adult\|family\|bot_sku\|server_id\|server\b" routes/checkout.js routes/trial.js 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -20
echo
echo "########## servers table: fields that shape a product card (name,image,type,etc.) ##########"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query('SELECT column_name FROM information_schema.columns WHERE table_name=\$1 ORDER BY ordinal_position',['servers']).then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -4
echo DONE
