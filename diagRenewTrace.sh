#!/usr/bin/env bash
# diagRenewTrace — the actual recent renewal order (content_type vs renew_line.version), the bridge API contract for
# renew/submit (does whatsapp trigger a customer notify?), whether submitOrder also passes whatsapp, and the website's
# own renewal notify path. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### recent renewal orders: content_type vs fields.renew_line.version vs delivered ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT order_no, product_name, plan_label, content_type, status, bot_order_id, left(coalesce(delivered_credentials,''),60) dc, fields->'renew_line' rl, fields->'renew_of' ro, created_at FROM orders WHERE (fields ? 'renew_line' OR fields ? 'renew_of') ORDER BY id DESC LIMIT 6\").then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -8
echo
echo "### botapi.js FULL HEADER (bridge API contract — renew/submit/whatsapp/notify semantics) ###"
sed -n '1,40p' lib/botapi.js
echo
echo "### does submitOrder (new orders) also pass whatsapp? (compare to renew) ###"
grep -n "whatsapp\|userPhone\|notify\|submitOrder(" routes/checkout.js | grep -iE "submitorder|whatsapp|userphone|notify" | head -15
echo
echo "### website's OWN renewal customer-notify (finalize/notifyOrder/deliver) ###"
grep -rn "notifyOrder\|emailOrder\|function finalize\|markDelivered\|customerWa\|wanotify\|deliveryMsg" routes/checkout.js lib/deliver.js 2>/dev/null | grep -v node_modules | head -20
echo DONE
