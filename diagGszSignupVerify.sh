#!/usr/bin/env bash
# diagGszSignupVerify — scope the verification mirror (#1): galaxyzayron signup, its outbound WhatsApp send
# path (to reuse for the forward OTP), the current wa-verify (reverse) flow, and the checkout/trial gate.
# READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ signup route (where the account is created) ############"
grep -n "signup\|register\|INSERT INTO customers\|router.post('/account/signup\|router.post('/signup" routes/account.js | head
echo "--- signup handler body (approx) ---"
sed -n '140,185p' routes/account.js
echo
echo "############ outbound WhatsApp send path (wanotify -> bot /send) ############"
grep -n "wa_bot_send_url\|postSend\|sendUrl\|/send\|destination_phone\|resolveRecipient" lib/wanotify.js | head
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  const ws=(await p.query("SELECT key,value FROM wa_settings WHERE key IN ('wa_bot_send_url','wa_verification_enabled','wa_required_for_checkout','wa_required_for_trials','wa_verify_number','site_base_url','wa_credentials_mode')")).rows;
  ws.forEach(r=>console.log("  ",r.key,"=",r.value));
  const ct=(await p.query("SELECT column_name FROM information_schema.columns WHERE table_name='customer_tokens' ORDER BY ordinal_position")).rows.map(x=>x.column_name);
  console.log("customer_tokens cols:", ct.join(", "));
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
echo
echo "############ how wa_verified is set today (reverse flow) + the webhook handler ############"
grep -rn "wa_verified\|current_phone_verified\|verified_at=now\|customer_whatsapp_links.*ACTIVE\|/webhook\|incoming" routes/whatsapp.js 2>/dev/null | head -25
echo
echo "############ the gate: where wa verification is required for checkout/trial ############"
grep -rn "wa_required_for_checkout\|wa_required_for_trials\|wa_verified\|verifyWa\|requireWaVerified\|_ivWaVerified" routes/checkout.js routes/trial.js routes/account.js 2>/dev/null | head -20
echo DONE
