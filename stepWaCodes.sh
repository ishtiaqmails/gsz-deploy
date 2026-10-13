#!/usr/bin/env bash
# stepWaCodes.sh — deliver account codes over WhatsApp (no email needed).
#   - routes/account.js: verification code + password-reset code are enqueued to the
#     customer's WhatsApp (enqueue by customer_id resolves their wa_number); verify page
#     no longer tells users to check email / add SMTP.
#   - seeds the whatsapp.email_verify template.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-wacodes-$TS"; cd "$GSZ"
RT=routes/account.js; VV=views/account/verify_email.ejs
for f in "$RT" "$VV"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f" 2>/dev/null || true; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$RT" "$GSZ/$RT" 2>/dev/null || true; cp "$BK/$VV" "$GSZ/$VV" 2>/dev/null || true; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> seed whatsapp.email_verify template"
node -e "const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});const{Pool}=require(R+'/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{await p.query(\"INSERT INTO wa_templates(key,body) VALUES('whatsapp.email_verify','Your {{site_name}} verification code is {{code}}. It expires in 30 minutes. If you did not create an account, you can ignore this message.') ON CONFLICT(key) DO NOTHING\");await p.end();console.log('   template ready');})().catch(e=>{console.error('   seed FAIL '+e.message);process.exit(1);});"

echo "==> patch account.js + verify page"
node "$SRC/patch_wacodes.js"

echo "==> checks"
node --check "$GSZ/$RT" && echo "   account.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$VV';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   verify_email.ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — verification + password-reset codes now sent over WhatsApp"
