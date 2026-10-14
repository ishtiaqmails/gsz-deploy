#!/usr/bin/env bash
# stepPreMsgBot.sh — website composes the premium delivery for BOT orders from the bot `fields`.
#   1) deploy lib/deliveryMsg.js (composer)
#   2) add wa_templates 'whatsapp.raw' = {{body}} (passthrough for composed messages)
#   3) patch routes/checkout.js + lib/deliver.js to compose+send for bot orders (fallback safe)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-premsgbot-$TS"; cd "$GSZ"
CO=routes/checkout.js; DV=lib/deliver.js
mkdir -p "$BK/routes" "$BK/lib"
cp "$GSZ/$CO" "$BK/$CO"; cp "$GSZ/$DV" "$BK/$DV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$CO" "$GSZ/$CO"; cp "$BK/$DV" "$GSZ/$DV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> 1) deploy composer"
cp -f "$SRC/deliveryMsg.js" "$GSZ/lib/deliveryMsg.js"
node --check "$GSZ/lib/deliveryMsg.js" && echo "   deliveryMsg.js ok"

echo "==> 2) add whatsapp.raw passthrough template"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ await p.query(\"INSERT INTO wa_templates(key,body) VALUES('whatsapp.raw','{{body}}') ON CONFLICT (key) DO UPDATE SET body=EXCLUDED.body\"); console.log('   whatsapp.raw ready'); await p.end(); })().catch(e=>{console.error(e.message);process.exit(1);});
"

echo "==> 3) patch checkout.js + deliver.js"
node "$SRC/patch_premsg_bot.js" "$GSZ"
node --check "$GSZ/$CO" && echo "   checkout.js ok"
node --check "$GSZ/$DV" && echo "   deliver.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — bot orders now deliver the website's premium message (data from bot, How-to-Use/Warranty from your admin). Fallback to raw text if fields missing."
