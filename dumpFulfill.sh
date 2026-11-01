#!/usr/bin/env bash
# dumpFulfill.sh — READ ONLY. How the website fulfils orders/trials through the reseller bot:
# the delivery path, the bot bridge (DB/API/queue), product->bot mapping, trial flow, and the
# recent Mega OTT trial that didn't deliver. Targeted output.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== how delivery/fulfilment is wired (files + bridge) ====="
grep -rilE "reseller|fulfil|deliver|bot.?bridge|activation_api|provision|megaott|mega_ott" lib routes 2>/dev/null | grep -vE '\.bak' | head -30

echo
echo "===== the bridge: DB-shared? HTTP API? queue? (connection hints) ====="
grep -rnE "RESELLER|BOT_|bot_db|botPool|activationpanel|megaott\.net|api/v1|axios|fetch\(|http\.request|new Pool" lib routes 2>/dev/null | grep -iE "reseller|bot|mega|deliver|fulfil|provision|activation" | grep -vE '\.bak' | head -30

echo
echo "===== product -> bot mapping model (the /admin/mapping system) ====="
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const t=(await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%map%' OR table_name ILIKE '%bot%' OR table_name ILIKE '%deliver%' OR table_name ILIKE '%fulfil%' OR table_name ILIKE '%trial%' OR table_name ILIKE '%provision%') ORDER BY table_name")).rows.map(r=>r.table_name);
  console.log('  tables:', t.join(', ')||'(none)');
  for(const tb of t){const c=(await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",[tb])).rows.map(x=>x.column_name);console.log('  ['+tb+'] '+c.join(', '));}
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE

echo
echo "===== trial flow: where a trial request is created + delivered ====="
grep -rnE "trial" routes/*.js 2>/dev/null | grep -ivE '\.bak' | grep -iE "insert|deliver|bot|send|provision|status|pending" | head -20
