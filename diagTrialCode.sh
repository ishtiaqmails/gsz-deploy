#!/usr/bin/env bash
# READ-ONLY. Grabs trials+customers schema and the exact trial.js regions to anchor the delivery + 1-time-verify edits.
set -e
Z=/opt/zayron; cd "$Z"
echo "### trials columns ###"
node -e "const{pool}=require('./db');(async()=>{try{const r=await pool.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='trials' ORDER BY ordinal_position\");for(const x of r.rows)console.log(x.column_name,'|',x.data_type);}catch(e){console.log('ERR',e.message)}process.exit(0)})()"
echo
echo "### customers columns (phone/verify related) ###"
node -e "const{pool}=require('./db');(async()=>{try{const r=await pool.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='customers' ORDER BY ordinal_position\");for(const x of r.rows)console.log(x.column_name,'|',x.data_type);}catch(e){console.log('ERR',e.message)}process.exit(0)})()"
echo
echo "### route + status/ready anchors in trial.js ###"
grep -nE "router\.(get|post)|pollWebTrial|enqueueWebTrial|claim_token|_skipOtp|phone_verified|status|ready|\.credentials|cookie" routes/trial.js | head -60
echo
echo "### POST /trial/start region (120-200) ###"
sed -n '120,200p' routes/trial.js
echo
echo "### status/ready region (250,345) ###"
sed -n '250,345p' routes/trial.js
echo "DONE"
