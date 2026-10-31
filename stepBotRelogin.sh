#!/usr/bin/env bash
# stepBotRelogin.sh — fresh WhatsApp login for the verification bot (gszwabot).
# The bot authenticates but its WhatsApp session is corrupted (init-queries timeout
# + Bad MAC). This backs up the Baileys session folder (reversible — it MOVES, never
# deletes) and restarts the bot so it shows a NEW QR on /admin/wabot to rescan.
# You must scan that QR from the bot's phone (447482794086).
set -uo pipefail
BOT=/opt/gsz-wabot
APP=gszwabot
TS=$(date +%s)

echo "==> locating the Baileys session folder (contains creds.json)"
CREDS=$(find "$BOT" -maxdepth 3 -name creds.json -not -path '*/node_modules/*' 2>/dev/null | head -1)
if [ -z "$CREDS" ]; then
  echo "!! Could not find a Baileys creds.json under $BOT."
  echo "   Paste the output of:  ls -la $BOT   and I'll pinpoint the session folder."
  exit 1
fi
AUTHDIR=$(dirname "$CREDS")
echo "   session folder: $AUTHDIR"

echo "==> stop bot, back up session, restart"
pm2 stop "$APP" >/dev/null 2>&1 || true
mv "$AUTHDIR" "$AUTHDIR.bak.$TS"
echo "   backed up -> $AUTHDIR.bak.$TS"
pm2 restart "$APP" --update-env >/dev/null 2>&1 || pm2 start "$APP" >/dev/null 2>&1
sleep 3
pm2 restart "$APP" >/dev/null 2>&1 || true

echo
echo "DONE. Now:"
echo "  1) Open  https://galaxyzayron.store/admin/wabot"
echo "  2) A QR code should appear within ~15s — scan it from the bot's phone (447482794086)"
echo
echo "If it does NOT connect after scanning, the number itself is likely rate-limited/flagged"
echo "— tell me and we'll check that / update Baileys."
echo
echo "To UNDO (restore the old session):"
echo "  pm2 stop $APP; rm -rf \"$AUTHDIR\"; mv \"$AUTHDIR.bak.$TS\" \"$AUTHDIR\"; pm2 restart $APP"
