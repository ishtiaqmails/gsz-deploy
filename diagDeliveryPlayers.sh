#!/usr/bin/env bash
# diagDeliveryPlayers — galaxyzayron's premium delivery composer + where "Players" (and DNS) come from the reseller
# bot, and zayron's current delivery + what the bridge returns for it. For zayron's premium delivery message. READ-ONLY.
set +e
echo "########## galaxyzayron lib/deliveryMsg.js (FULL premium composer) ##########"
cd /opt/gsz && wc -l lib/deliveryMsg.js; sed -n '1,200p' lib/deliveryMsg.js
echo
echo "########## galaxyzayron: where PLAYERS + DNS come from the bot (order fields / delivered_credentials) ##########"
grep -rn "player\|Player\|PLAYER\|apps\|app_links\|dns\|DNS\|host\|m3u\|delivered_credentials\|st.fields\|order-status\|fields.details" routes/checkout.js lib/deliveryMsg.js lib/botapi.js 2>/dev/null | grep -iE "player|app|dns|\.details|delivered_cred" | head -25
echo
echo "########## zayron: what the bridge order-status returns (fields/details/players) ##########"
cd /opt/zayron && grep -n "details\|player\|app\|dns\|host\|m3u\|fields\|delivered_credentials\|extractLine\|orderStatus" lib/orderDispatch.js lib/gszApi.js | head -25
echo
echo "########## zayron: order columns available for the delivery message ##########"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' ORDER BY ordinal_position\").then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -4
echo DONE
