#!/usr/bin/env bash
# diagAllBotMessages — every WhatsApp message each website sends. READ-ONLY.
set +e
echo "############################################################"
echo "#  GALAXYZAYRON.STORE — wa_templates (all bot messages)    #"
echo "############################################################"
cd /opt/gsz && node -e "
const {Pool}=require('pg');require('dotenv').config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
p.query(\"SELECT key, body FROM wa_templates ORDER BY key\").then(r=>{
  r.rows.forEach(x=>{ console.log('\n===== '+x.key+' ====='); console.log((x.body||'(empty)')); });
  console.log('\n('+r.rows.length+' templates)');
  return p.end();
}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1
echo
echo "----- galaxyzayron: the site-OTP verification text (composed in code, branded per site) -----"
cd /opt/gsz && grep -n "verification code is:" routes/whatsapp.js | head
echo
echo "----- galaxyzayron: delivery message builder (lib/deliveryMsg.js header/format) -----"
cd /opt/gsz && sed -n '1,30p' lib/deliveryMsg.js 2>/dev/null
echo
echo "############################################################"
echo "#  ZAYRON.TV — message strings (OTP / verify / reset)      #"
echo "############################################################"
echo "----- zayron: does it have a templates table? -----"
cd /opt/zayron && node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%templ%' OR table_name ILIKE '%message%'\").then(r=>{console.log(r.rows.map(x=>x.table_name).join(', ')||'(none — messages are inline in code)');return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -3
echo
echo "----- zayron: all inline bot message texts -----"
cd /opt/zayron && grep -rhn "verification code is\|password reset code\|Your Zayron\|Your zayron" routes lib 2>/dev/null | grep -v node_modules | grep -v "\.bak" | sed "s/^[0-9]*://" | sed "s/^[[:space:]]*//" | sort -u | head -40
echo DONE
