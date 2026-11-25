#!/usr/bin/env bash
# diagRedirectBrand — exact compose sites for verification_success + redirect_support, the sender lookup available
# there, and the gsz brand/contact settings, to make both self-aware. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "### verification_success compose (+context) ###"
grep -n "verification_success" routes/whatsapp.js
L=$(grep -n "whatsapp.verification_success" routes/whatsapp.js | tail -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-3)),$((L+2))p" routes/whatsapp.js
echo
echo "### redirect_support compose (+ ~22 lines before it: the no-match fallback + sender info) ###"
R=$(grep -n "whatsapp.redirect_support" routes/whatsapp.js | head -1 | cut -d: -f1)
[ -n "$R" ] && sed -n "$((R-22)),$((R+3))p" routes/whatsapp.js
echo
echo "### is a galaxyzayron-customer lookup helper available? (by phone/lid) ###"
grep -n "function waWho\|customer_whatsapp_links\|current_phone_e164\|i.lid=\|SELECT c.id, c.name" routes/whatsapp.js | head -8
echo
echo "### gsz brand + contact settings ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT key,value FROM wa_settings WHERE key IN ('site_base_url','site_name','wa_sales_number','wa_support_number','wa_verify_number','sister_site_url','sister_sales_number') ORDER BY key\").then(r=>{r.rows.forEach(x=>console.log('  '+x.key+' = '+x.value));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -8
echo DONE
