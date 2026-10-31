#!/usr/bin/env bash
# stepBotRelogin2.sh — fresh WhatsApp login, targeting the LIVE session folder
# (/opt/gsz-wabot/auth) explicitly. Backs up (moves, reversible) the corrupted
# live session so the bot shows a NEW QR on /admin/wabot. Also restores the stale
# backup my previous script mis-renamed, so no junk is left behind.
set -uo pipefail
BOT=/opt/gsz-wabot
APP=gszwabot
AUTH="$BOT/auth"
TS=$(date +%s)

# 0) undo my earlier mis-rename (restore the Oct-12 backup's original name)
STRAY="$BOT/auth.bak-20261012-034812.bak.1793478437"
if [ -d "$STRAY" ]; then mv "$STRAY" "$BOT/auth.bak-20261012-034812" 2>/dev/null && echo "==> restored stale backup name (cleanup)"; fi

# 1) sanity: the live auth folder must exist and look like a Baileys store
if [ ! -f "$AUTH/creds.json" ]; then
  echo "!! $AUTH/creds.json not found — stopping so nothing is disturbed."; exit 1
fi
echo "==> live session: $AUTH  (has creds.json)"

# 2) stop, back up the LIVE session, restart for a fresh QR
pm2 stop "$APP" >/dev/null 2>&1 || true
mv "$AUTH" "$BOT/auth.corrupt.$TS"
echo "   live session backed up -> $BOT/auth.corrupt.$TS"
pm2 restart "$APP" --update-env >/dev/null 2>&1 || pm2 start "$BOT/bot.js" --name "$APP" >/dev/null 2>&1
sleep 3
pm2 restart "$APP" >/dev/null 2>&1 || true

echo
echo "DONE. Now:"
echo "  1) Open  https://galaxyzayron.store/admin/wabot"
echo "  2) A QR should appear within ~15s — scan from the bot's phone (447482794086):"
echo "     WhatsApp > Linked Devices > Link a Device"
echo
echo "UNDO (restore the old session if needed):"
echo "  pm2 stop $APP; rm -rf \"$AUTH\"; mv \"$BOT/auth.corrupt.$TS\" \"$AUTH\"; pm2 restart $APP"
