#!/usr/bin/env bash
# diagZayronWaPanel — zayron.tv's deploy path + how its dashboard shows the bot QR/status, how it reaches gszwabot
# (waSend.js), and gszwabot's own HTTP port + /status + logout. READ-ONLY. No secrets.
set +e
echo "########## zayron deploy path / repo ##########"
ls -d /opt/zayron-deploy /opt/zayron/.git 2>/dev/null
cd /opt/zayron 2>/dev/null && { echo "zayron git remote:"; git remote -v 2>/dev/null | head -2; echo "is /opt/zayron a working tree? $( [ -d .git ] && echo yes || echo no )"; }
[ -d /opt/zayron-deploy ] && { cd /opt/zayron-deploy && echo "zayron-deploy remote:"; git remote -v 2>/dev/null | head -2; ls *.sh 2>/dev/null | head; }
echo
echo "########## /opt/zayron/lib/waSend.js — how zayron reaches gszwabot (base url/port) ##########"
cd /opt/zayron && { ls lib/waSend.js 2>/dev/null && grep -n "http\|127.0.0.1\|localhost\|:8095\|:\s*[0-9]\{4\}\|PORT\|/send\|/status\|URL\|fetch\|request\|BOT" lib/waSend.js | head -20; }
echo
echo "########## gszwabot: HTTP port it listens on + /status + logout endpoints ##########"
cd /opt/gsz-wabot && { grep -n "createServer\|listen(\|PORT\|8095\|'/status'\|\"/status\"\|/relogin\|/logout\|logout\|rmSync\|rimraf\|AUTH_DIR" bot.js | head -25; echo "-- .env PORT --"; grep -E '^(PORT|HTTP_PORT|SEND_PORT)=' .env 2>/dev/null; }
echo
echo "########## zayron LIVE admin.js — the bot/QR/status section (live file, not .bak) ##########"
cd /opt/zayron && { echo "live admin route file(s):"; ls -la routes/admin.js 2>/dev/null; echo "-- lines around the QR/status render --"; grep -n "otp_status\|st.qr\|preparing a QR\|Verification Bot\|/admin/.*whatsapp\|/admin/.*bot\|bot status\|wa status\|qr.indexOf\|reconnect\|relogin\|logout" routes/admin.js 2>/dev/null | head -30; }
echo
echo "########## how zayron reads otp_status for the panel ##########"
cd /opt/zayron && grep -rn "otp_status\|otp_outbox" routes lib 2>/dev/null | grep -v node_modules | grep -v "\.bak" | head -15
echo DONE
