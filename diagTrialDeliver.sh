#!/usr/bin/env bash
# READ-ONLY. Shows why the trial isn't landing on WhatsApp + what the trial code does on "ready".
set -e
Z=/opt/zayron; cd "$Z"
echo "### latest trials (id/server/status/request_id/phone/created) ###"
node -e "const{pool}=require('./db');(async()=>{try{const r=await pool.query(\"SELECT id,server_id,status,request_id,phone,claim_token,created_at FROM trials ORDER BY id DESC LIMIT 4\");for(const x of r.rows)console.log(JSON.stringify(x));}catch(e){console.log('ERR',e.message)}process.exit(0)})()"
echo
echo "### does trial.js send WhatsApp on ready? (waSend / send / notify / outbox) ###"
grep -nE "waSend|\\.send\\(|notify|otp_outbox|outbox|wa_outbox|sendTrial|deliverTrial" routes/trial.js | head -20 || echo "(none found)"
echo
echo "### botQueue.js send/deliver lines ###"
grep -nE "waSend|\\.send\\(|notify|outbox|formatted|host|m3u" lib/botQueue.js | head -20 || echo "(none found)"
echo
echo "### last 5 otp_outbox rows (did ANY send go out?) ###"
node -e "const{pool}=require('./db');(async()=>{try{const r=await pool.query(\"SELECT id,phone,status,created_at,left(body,40) AS body FROM otp_outbox ORDER BY id DESC LIMIT 5\");for(const x of r.rows)console.log(JSON.stringify(x));}catch(e){console.log('ERR',e.message)}process.exit(0)})()"
echo
echo "### waSend self-test (does the bot accept a send right now?) ###"
node -e "const w=require('./lib/waSend');(async()=>{try{console.log('configured env:',!!process.env.GSZ_WABOT_URL||'(from .env)')}catch(e){}process.exit(0)})()"
echo "DONE"
