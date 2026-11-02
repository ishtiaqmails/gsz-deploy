#!/usr/bin/env bash
# stepTrialCleanup.sh — remove the dead Mega trial claims that failed with the bot's old
# "text is not iterable" error (pre-fix). Targeted: only failed claims with that exact bot_ref,
# so no legitimate trial record is touched.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const pre=(await pool.query("SELECT id FROM trial_claims WHERE status='failed' AND bot_ref='text is not iterable'")).rows.map(r=>r.id);
  const r=await pool.query("DELETE FROM trial_claims WHERE status='failed' AND bot_ref='text is not iterable'");
  console.log('removed '+r.rowCount+' dead Mega trial rows: '+(pre.join(', ')||'(none)'));
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE
