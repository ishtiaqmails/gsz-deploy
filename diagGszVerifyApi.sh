#!/usr/bin/env bash
# diagGszVerifyApi — exact /start + /status endpoints, the webhook head (parts + VERIFY regex), the waid identity
# resolver signature, wanotify usage, and the customers wa_number column. Last read before the site-OTP build. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ whatsapp.js: requires + /start + /status + webhook head (200-330) ############"
grep -n "require(\|router.post\|router.get\|verification/start\|verification/:id/status\|/internal/whatsapp/incoming\|waid\.\|wanotify\|wa_number\|wa_verify_mode\|resolveOrCreateIdentity\|const parts\|let parts\|m = \|match(" routes/whatsapp.js | head -60
echo "--- 205-330 ---"
sed -n '205,330p' routes/whatsapp.js
echo
echo "############ waid resolver: find + signature ############"
WF=$(grep -rln "resolveOrCreateIdentity" lib 2>/dev/null | head -1); echo "waid file: $WF"
[ -n "$WF" ] && grep -n "resolveOrCreateIdentity\|function\|canonical_lid\|current_phone\|INSERT INTO whatsapp_identities\|module.exports" "$WF" | head -30
echo
echo "############ customers columns: wa_number / wa_verified ############"
cd /opt/gsz && node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='customers' AND (column_name LIKE 'wa%' OR column_name LIKE '%whatsapp%' OR column_name='phone') ORDER BY column_name\").then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -3
echo DONE
