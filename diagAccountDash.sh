#!/usr/bin/env bash
# READ-ONLY. Account dashboard: subscriptions / trials / orders rendering + credential columns.
Z=/opt/zayron; cd "$Z"
echo "### / (subscriptions) 478-545 ###"; sed -n '478,545p' routes/account.js
echo; echo "### /trials 545-564 ###"; sed -n '545,564p' routes/account.js
echo; echo "### /orders 564-597 ###"; sed -n '564,597p' routes/account.js
echo; echo "### trials + orders credential columns ###"
node -e "const{pool}=require('./db');(async()=>{for(const t of ['trials','orders']){const r=await pool.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='\$1' ORDER BY ordinal_position\".replace('\$1',t));console.log(t+':',r.rows.map(x=>x.column_name).join(', '));}process.exit(0)})().catch(e=>{console.log(e.message);process.exit(0)})"
echo DONE
