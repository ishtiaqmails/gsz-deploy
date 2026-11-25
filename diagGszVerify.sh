#!/usr/bin/env bash
# diagGszVerify — how galaxyzayron (/opt/gsz) verifies a customer's WhatsApp today (to be mirrored to the
# zayron.tv style: site generates code -> sends to customer -> customer enters on site). Also: where an admin
# toggle fits, and whether the site can already send a message to a customer's number. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ verification-related routes in account.js ############"
grep -n "verify\|otp\|whatsapp_link\|whatsapp-link\|link.*whatsapp\|identity\|send.*code\|code.*send\|phone_verified\|wa_verify" routes/account.js | head -40
echo
echo "############ customers table: verification columns ############"
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  for(const t of ['customers','customer_whatsapp_links','whatsapp_identities','wa_settings','otp_outbox']){
    const c=(await p.query("SELECT column_name FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",[t])).rows.map(x=>x.column_name);
    console.log(t+":", c.length?c.join(", "):"(no such table)");
  }
  const ws=(await p.query("SELECT key FROM wa_settings ORDER BY key")).rows.map(x=>x.key);
  console.log("\nwa_settings keys:", ws.join(", ")||"(none)");
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
echo
echo "############ how the site currently sends WhatsApp to a customer (wanotify / identity) ############"
grep -n "enqueue\|whatsapp_identity_id\|customer_whatsapp_links\|is_primary\|template_key\|sendText\|function" lib/wanotify.js | head -40
echo
echo "############ does galaxyzayron have anything like zayron's otp_outbox drain? ############"
grep -rln "otp_outbox\|verification code\|verify.*code\|enter.*code" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head
echo DONE
