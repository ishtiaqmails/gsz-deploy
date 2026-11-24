#!/usr/bin/env bash
# READ-ONLY. Shows the exact galaxyzayron-formatted trial block (so the zayron WhatsApp msg can match it).
echo "### latest trial_requests.credentials (the house format the bot produced) ###"
node -e "const db=require('/opt/galaxybot/src/db');(async()=>{try{const r=await db.query(\"SELECT request_id,status,left(credentials,1200) c FROM trial_requests WHERE credentials IS NOT NULL ORDER BY updated_at DESC NULLS LAST LIMIT 2\");for(const x of r.rows){console.log('--- '+x.request_id+' ('+x.status+') ---');console.log(x.c);console.log()}}catch(e){console.log('ERR',e.message)}process.exit(0)})()"
echo "### and the latest PAID order delivered_credentials (galaxyzayron buy format) for reference ###"
node -e "const db=require('/opt/galaxybot/src/db');(async()=>{try{const r=await db.query(\"SELECT order_no,left(delivered_credentials,1200) c FROM orders WHERE delivered_credentials IS NOT NULL AND delivery_type='iptv' ORDER BY id DESC LIMIT 1\");for(const x of r.rows){console.log('--- order '+x.order_no+' ---');console.log(x.c)}}catch(e){console.log('ERR',e.message)}process.exit(0)})()"
echo DONE
