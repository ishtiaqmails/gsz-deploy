#!/usr/bin/env bash
# diagZayronOtpBridge — exact otp_status keys zayron's panel reads, the full zayron-otp sender, gszwabot /status
# response shape, and whether qrcode is available. READ-ONLY. Last read before building the bridge.
set +e
echo "########## zayron admin.js WhatsApp panel (3345-3415): which otp_status keys it reads + render + poll ##########"
cd /opt/zayron && sed -n '3345,3415p' routes/admin.js
echo
echo "########## any zayron admin JSON status/poll endpoint for the bot ##########"
cd /opt/zayron && grep -n "res.json\|/status\|/wa-status\|/bot/status\|setInterval\|fetch('/admin\|qr.json\|reset_requested\|relogin\|reconnect\|Reconnect\|Re-scan\|rescan" routes/admin.js | grep -i "status\|qr\|reset\|relogin\|reconnect\|scan\|json" | head -25
echo
echo "########## FULL zayron-otp/index.js (the sender to rewrite as the bridge) ##########"
cat /opt/zayron-otp/index.js
echo
echo "########## gszwabot /status response shape (144-192) ##########"
sed -n '144,192p' /opt/gsz-wabot/bot.js
echo
echo "########## qrcode availability ##########"
for d in /opt/zayron-otp /opt/zayron /opt/gsz; do echo -n "$d/node_modules/qrcode: "; [ -d "$d/node_modules/qrcode" ] && echo yes || echo no; done
echo "zayron-otp .env (non-secret keys):"; grep -vE 'SECRET|TOKEN|KEY|PASS' /opt/zayron-otp/.env 2>/dev/null | head
echo DONE
