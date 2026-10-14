#!/usr/bin/env bash
# stepNfLiveCleanup.sh — remove ALL live-test data from stepNfLiveTest.sh. Safe to re-run.
set -euo pipefail
GSZ=/opt/gsz; cd "$GSZ"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const a=(await p.query(\"DELETE FROM nf_assignments WHERE order_no='NFLIVE-GSZ'\")).rowCount;
  const o=(await p.query(\"DELETE FROM orders WHERE order_no='NFLIVE-GSZ'\")).rowCount;
  const n=(await p.query(\"DELETE FROM nf_accounts WHERE account_email='nflive-demo@demo.local'\")).rowCount;
  console.log('LIVE CLEANUP DONE -> assignments:'+a+' orders:'+o+' nf_accounts:'+n);
  await p.end();
})().catch(e=>{console.error('CLEANUP FAIL:',e.message);process.exit(1);});
"
