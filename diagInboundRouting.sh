#!/usr/bin/env bash
# diagInboundRouting — do zayron.tv and galaxyzayron share ONE inbound verification bot/number, and where does the
# bot forward inbound chatter? READ-ONLY. No secrets printed (only WEBSITE_BASE/PORT/site keys).
set +e
echo "### pm2 processes (which bots run) ###"
pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{JSON.parse(d).forEach(p=>console.log('- '+p.name+'  ['+(p.pm2_env&&p.pm2_env.status)+']  cwd='+((p.pm2_env&&p.pm2_env.pm_cwd)||'')));}catch(e){console.log('(pm2 jlist parse err)');}});" 2>/dev/null
echo
echo "### bot/wabot directories on the box ###"
ls -d /opt/*wabot* /opt/*-wabot /opt/*bot 2>/dev/null | grep -v node_modules
echo
echo "### each wabot: WEBSITE_BASE / PORT / SITE / any routing (non-secret env keys only) ###"
for d in /opt/gsz-wabot /opt/zayron-wabot /opt/*wabot*; do
  [ -d "$d" ] || continue
  echo "--- $d ---"
  [ -f "$d/.env" ] && grep -E '^(WEBSITE_BASE|PORT|SITE|SITE_BASE|BRAND|WA_|SEND_|BOT_NAME)=' "$d/.env" | grep -iv 'secret\|token\|key\|pass\|session' 
  [ -f "$d/bot.js" ] && grep -n "WEBSITE_BASE\|forward\|incoming\|/internal/whatsapp\|3500\|3900\|which site\|brand\|route" "$d/bot.js" | head -15
done
echo
echo "### galaxyzayron (gsz) verification number + site ###"
cd /opt/gsz && node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT key,value FROM wa_settings WHERE key IN ('wa_verify_number','wa_number','site_base_url','site_name','wa_bot_webhook_secret') ORDER BY key\").then(r=>{r.rows.forEach(x=>console.log('gsz  '+x.key+' = '+(x.key.indexOf('secret')>=0?('('+(x.value?'set':'empty')+')'):x.value)));return p.end();}).catch(e=>{console.log('gsz ERR',e.message);process.exit(0);});" 2>&1 | tail -8
echo
echo "### zayron.tv verification number + site (its own DB) ###"
cd /opt/zayron && node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const cols=await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_name IN ('wa_settings','settings','site_settings')\");console.log('zayron settings tables:',cols.rows.map(x=>x.table_name).join(', ')||'(none)');for(const tn of cols.rows.map(x=>x.table_name)){try{const r=await p.query('SELECT key,value FROM '+tn+\" WHERE key ILIKE '%wa_%number%' OR key ILIKE '%verify%' OR key ILIKE '%whatsapp%number%' OR key='wa_number' OR key ILIKE 'site_%' LIMIT 20\");r.rows.forEach(x=>console.log('zayron ['+tn+']  '+x.key+' = '+x.value));}catch(e){console.log(tn,'q err',e.message);}}}catch(e){console.log('zayron ERR',e.message);}await p.end();})();" 2>&1 | tail -20
echo DONE
