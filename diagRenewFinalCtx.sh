#!/usr/bin/env bash
# diagRenewFinalCtx — field_data column type (jsonb/text) + exact runCollect loop line + whether field_data is used
# elsewhere, to wire renewal safely. READ-ONLY.
set +e
cd /opt/zayron || exit 0
echo "### field_data column type ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='orders' AND column_name IN ('field_data','fields','kind','renew_username','expires_at')\").then(r=>{r.rows.forEach(x=>console.log('  '+x.column_name+' : '+x.data_type));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -6
echo
echo "### runCollect loop (the poll line + done/failed branches) exact ###"
grep -n "const p = await dispatch.poll\|p.status === 'done'\|p.status === 'failed'\|for (const o of rows)" lib/orderWorker.js | head
echo
echo "### is field_data read anywhere (don't break it)? ###"
grep -rn "field_data" routes lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -15
echo
echo "### dispatch module exports (to add renewLine + pollRenew) ###"
grep -n "module.exports" lib/orderDispatch.js
echo DONE
