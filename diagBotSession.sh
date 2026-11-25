#!/usr/bin/env bash
# diagBotSession — map the WhatsApp bot QR/pairing/session + how EACH dashboard (galaxyzayron + zayron.tv) reads
# bot status/QR/number, so a single scan can drive both. READ-ONLY. No secrets/creds printed.
set +e
echo "########## pm2: gszwabot + zayron-otp (what they are) ##########"
for P in gszwabot zayron-otp; do
  echo "--- $P ---"
  pm2 describe "$P" 2>/dev/null | grep -E "script path|exec cwd|script args|node args|status|restarts" | head -6
done
echo
echo "########## gszwabot/bot.js — QR / pairing / session / status-forward / number ##########"
cd /opt/gsz-wabot 2>/dev/null && { grep -n "qr\|QR\|pairing\|pairingCode\|useMultiFileAuthState\|authState\|saveCreds\|creds\|connection\.update\|me\.id\|jidNormalized\|WEBSITE_BASE\|postWebhook\|/status\|/qr\|bot_status\|status.*CONNECTED\|number" bot.js | head -40; echo "--- auth/session dir ---"; ls -la 2>/dev/null | grep -iE "auth|session|creds|baileys" | head; grep -n "WEBSITE_BASE\|SECOND\|OTHER\|SITES\|,3500\|3500" .env bot.js 2>/dev/null | head; }
echo
echo "########## galaxyzayron dashboard WhatsApp panel — where QR/status/number come from ##########"
cd /opt/gsz 2>/dev/null && { echo "-- routes referencing qr/bot status/verify number --"; grep -rn "qr\|QR\|wa_bot_status\|wa_verify_number\|bot_number\|pairing\|/send\|wa_bot_send_url\|CONNECTED" routes/wabot.js routes/adminWhatsapp.js 2>/dev/null | head -30; }
echo
echo "########## zayron.tv dashboard WhatsApp section — where it reads QR/status/number ##########"
cd /opt/zayron 2>/dev/null && { F=$(grep -rln "whatsapp\|wabot\|qr\|QR\|verify_number\|bot_status\|baileys\|WEBSITE_BASE" routes 2>/dev/null | grep -v node_modules | head -8); echo "candidate route files:"; echo "$F"; for f in $F; do echo "== $f =="; grep -n "qr\|QR\|bot_status\|verify_number\|wa_number\|WEBSITE_BASE\|8095\|447482794086\|/send\|pairing\|CONNECTED\|whatsapp_number" "$f" | head -12; done; }
echo
echo "########## zayron-otp — is it zayron's own bot/session? (number, baileys, forward target) ##########"
cd /opt/zayron-otp 2>/dev/null && { ls -la | head; echo "-- main/index --"; MAIN=$(node -e "try{console.log(require('./package.json').main||'index.js')}catch(e){console.log('index.js')}" 2>/dev/null); echo "main=$MAIN"; grep -n "baileys\|useMultiFileAuthState\|qr\|QR\|WEBSITE_BASE\|447482794086\|number\|me\.id\|forward\|/send\|PORT\|otp\|verify" "$MAIN" 2>/dev/null | head -25; } || echo "(no /opt/zayron-otp)"
echo DONE
