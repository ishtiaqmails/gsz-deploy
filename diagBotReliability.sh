#!/usr/bin/env bash
# diagBotReliability — gszwabot Baileys version + socket config + send logic + session handling, to diagnose the
# "Waiting for this message" multi-device decryption issue. READ-ONLY.
set +e
cd /opt/gsz-wabot || { echo "no /opt/gsz-wabot"; exit 0; }
echo "### Baileys version ###"
node -e "try{console.log('baileys:', require('@whiskeysockets/baileys/package.json').version)}catch(e){console.log('ver err',e.message)}" 2>/dev/null
grep -E '"@whiskeysockets/baileys"' package.json 2>/dev/null
echo
echo "### makeWASocket config (socket options) ###"
grep -n "makeWASocket\|version\|browser\|syncFullHistory\|shouldSyncHistory\|markOnlineOnConnect\|getMessage\|generateHighQuality\|retryRequestDelayMs\|msgRetryCounterCache\|fireInitQueries\|emitOwnEvents\|cachedGroupMetadata\|patchMessageBeforeSending" bot.js | head -30
echo "--- the socket creation block ---"
L=$(grep -n "makeWASocket(" bot.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "$((L-2)),$((L+20))p" bot.js
echo
echo "### send function (how it sends + retries) ###"
L2=$(grep -n "sendText\|sendMessage(\|function send\|async function send" bot.js | head -1 | cut -d: -f1); [ -n "$L2" ] && sed -n "$((L2-2)),$((L2+20))p" bot.js
echo
echo "### connection.update / reconnect / session handling + any decrypt/retry handling ###"
grep -n "connection.update\|lastDisconnect\|DisconnectReason\|Bad MAC\|decrypt\|retry\|session\|close\|reconnect\|QR\|clearState\|logout" bot.js | head -25
echo
echo "### restarts (session instability?) ###"
pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='gszwabot');console.log('gszwabot restarts:',(p&&p.pm2_env&&p.pm2_env.restart_time)||'?','status:',(p&&p.pm2_env&&p.pm2_env.status));}catch(e){}});" 2>/dev/null
echo "### recent bot log lines mentioning decrypt/retry/session/waiting ###"
pm2 logs gszwabot --nostream --lines 200 2>/dev/null | grep -iE "decrypt|bad mac|retry|session|waiting|prekey|precondition|failed" | tail -15
echo DONE
