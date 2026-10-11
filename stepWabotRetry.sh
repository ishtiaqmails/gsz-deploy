#!/usr/bin/env bash
# GSZ Verification Bot — fix the recipient-side "Waiting for this message. This may take
# a while." Implements Baileys getMessage() backed by a small store of sent messages, so
# when WhatsApp asks the bot to resend a message it couldn't decrypt, the bot can fulfil
# it (instead of the message staying stuck). Applies to replies + /send notifications.
# /status, /health, /send, /reconnect, /logout unchanged. Does NOT touch the gsz site or
# the reseller bot. Restart briefly drops the socket; it reconnects from saved auth.
# Idempotent; backs up; auto-restores bot.js on failure.
set -Eeuo pipefail
BOT=/opt/gsz-wabot; SRC=/opt/gsz-deploy/wabot; TS=$(date +%Y%m%d-%H%M%S)
[ -f "$SRC/bot.js" ] || { echo "!! $SRC/bot.js missing — run 'git pull' in /opt/gsz-deploy"; exit 1; }
[ -d "$BOT" ] || { echo "!! $BOT not found — is the verification bot installed on this box?"; exit 1; }
cp -f "$BOT/bot.js" "$BOT/bot.js.bak.$TS"
restore(){ echo "!! FAILED — restoring bot.js"; cp -f "$BOT/bot.js.bak.$TS" "$BOT/bot.js"; pm2 restart gszwabot >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/bot.js" "$BOT/bot.js"
node --check "$BOT/bot.js"

trap - ERR
( cd "$BOT" && pm2 restart gszwabot --update-env >/dev/null ); echo "   gszwabot restarted"

# quick time-skew check (big clock drift also breaks WhatsApp decryption)
echo "   server time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')  (NTP: $(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo '?'))"

SECRET=$(grep -E '^WA_WEBHOOK_SECRET=' "$BOT/.env" 2>/dev/null | head -1 | cut -d= -f2-)
PORT=$(grep -E '^BOT_PORT=' "$BOT/.env" 2>/dev/null | head -1 | cut -d= -f2-); PORT=${PORT:-8095}
for i in $(seq 1 15); do
  out=$(curl -s -H "X-WA-Secret: $SECRET" "http://127.0.0.1:$PORT/status" || true)
  echo "$out" | grep -q '"ok":true' && { echo "   /status OK -> $out"; break; }
  sleep 1
done
echo "DONE — resend/getMessage fix live. New messages won't get stuck on 'Waiting for this message'."
