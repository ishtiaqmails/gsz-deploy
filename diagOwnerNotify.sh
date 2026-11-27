#!/usr/bin/env bash
# diagOwnerNotify — how galaxyzayron notifies the OWNER on order events + zayron's order lifecycle hook points +
# zayron owner number(s). For porting owner order notifications to zayron. READ-ONLY.
set +e
echo "########## galaxyzayron: the owner-notify (botapi.notify) content + which events trigger it ##########"
cd /opt/gsz
echo "--- notifyOrder / owner-alert block (278-320) ---"
sed -n '278,320p' routes/checkout.js
echo "--- what events call notifyOrder (new/paid/delivered) ---"
grep -n "notifyOrder(" routes/checkout.js | head
echo
echo "########## zayron: order lifecycle — where orders are placed / verified / delivered ##########"
cd /opt/zayron
echo "--- order status transitions in checkout + worker ---"
grep -rn "status='verified'\|status='delivered'\|status = 'verified'\|INSERT INTO orders\|status='provisioning'\|status='paid'\|ownerAlert\|owner_notify\|notifyOwner" routes/checkout.js lib/orderWorker.js lib/orderDispatch.js 2>/dev/null | grep -v node_modules | head -20
echo "--- zayron bridge methods (has notify?) ---"
grep -n "module.exports" lib/gszApi.js | head -1
echo
echo "########## zayron owner number(s) in settings ##########"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT key,value FROM settings WHERE key ILIKE '%owner%' OR key ILIKE '%admin%' OR key ILIKE '%notify%' OR key='whatsapp_number' OR key ILIKE '%wa_%'\").then(r=>{r.rows.forEach(x=>console.log('  '+x.key+' = '+x.value));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -12
echo DONE
