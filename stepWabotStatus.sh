#!/usr/bin/env bash
# GSZ Verification Bot — add an admin control surface to /opt/gsz-wabot/bot.js:
#   GET  /status    -> { connected, number, qr, connectedAt, uptimeMs }  (secret-gated)
#   POST /reconnect -> drop + reconnect the socket
#   POST /logout    -> log the number out and start a fresh QR pairing
# /health and /send are unchanged, so website verification + notifications keep working.
# Restarting the bot briefly drops the WhatsApp socket; it reconnects from the saved
# session (auth/) within a few seconds — no re-scan needed. Does NOT touch the gsz site
# or the reseller bot. Idempotent; backs up; auto-restores bot.js on failure.
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

# verify the new /status endpoint answers (secret from the bot's own .env)
SECRET=$(grep -E '^WA_WEBHOOK_SECRET=' "$BOT/.env" 2>/dev/null | head -1 | cut -d= -f2-)
PORT=$(grep -E '^BOT_PORT=' "$BOT/.env" 2>/dev/null | head -1 | cut -d= -f2-); PORT=${PORT:-8095}
ok=""
for i in $(seq 1 15); do
  out=$(curl -s -H "X-WA-Secret: $SECRET" "http://127.0.0.1:$PORT/status" || true)
  echo "$out" | grep -q '"ok":true' && { ok="$out"; break; }
  sleep 1
done
if [ -n "$ok" ]; then echo "   /status OK -> $ok"; else echo "!! /status did not answer yet — check: pm2 logs gszwabot --lines 30"; fi
echo "DONE — verification bot now exposes /status, /reconnect, /logout (admin control surface ready)."
