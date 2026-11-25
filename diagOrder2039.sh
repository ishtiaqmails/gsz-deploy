#!/usr/bin/env bash
# diagOrder2039 — why GSZ-2039 is stuck in payment verification. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### GSZ-2039 order row ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT order_no,status,claim_result,amount_pkr,amount_claimed,method_key,method_name,txn_ref,proof_file,bot_sku,bot_plan_key,verified_at,created_at,fields FROM orders WHERE order_no='GSZ-2039'\").then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x,null,1)));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -30
echo
echo "### the verify flow: STATUS_MAP + verifyClaim handling + what runs the verify poll ###"
grep -n "STATUS_MAP\|verifyClaim\|status='verifying'\|'verifying'\|verifyLoop\|runVerify\|setInterval\|claim_result" routes/checkout.js | head -25
echo
echo "### recent pm2 logs for verify/claim (last 40 lines mentioning verify/claim/2039) ###"
pm2 logs gsz --nostream --lines 300 2>/dev/null | grep -iE "verify|claim|2039|genuine|underpaid|not_found" | tail -25
echo DONE
