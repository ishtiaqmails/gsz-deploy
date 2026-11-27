#!/usr/bin/env bash
# diagZayronDeliverExact — exact current zayron orderWorker delivery code (notifyDelivered + runCollect) + poll return,
# server-name lookup availability, and confirm lib/deliveryMsg.js doesn't exist yet. READ-ONLY.
set +e
cd /opt/zayron || exit 0
echo "### orderWorker.js 95-165 (notifyDelivered + runCollect) ###"
sed -n '95,165p' lib/orderWorker.js
echo
echo "### orderDispatch.poll (95-107) ###"
sed -n '95,107p' lib/orderDispatch.js
echo
echo "### waSend signature ###"
grep -n "function send\|module.exports\|async function" lib/waSend.js | head
echo
echo "### server name lookup: servers has name? + how order maps to server ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='servers' AND column_name IN ('id','name','slug')\").then(r=>{console.log('servers cols:',r.rows.map(x=>x.column_name).join(', '));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -3
echo "lib/deliveryMsg.js exists? $( [ -f lib/deliveryMsg.js ] && echo yes || echo NO )"
echo DONE
