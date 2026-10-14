#!/usr/bin/env bash
# stepSupportBot.sh — premium voice + plain labels for the on-site support chat.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-supportbot-$TS"; cd "$GSZ"
SB=lib/supportbot.js
mkdir -p "$BK/lib"; cp "$GSZ/$SB" "$BK/$SB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SB" "$GSZ/$SB"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch supportbot.js"
node "$SRC/patch_supportbot.js" "$GSZ"
node --check "$GSZ/$SB" && echo "   supportbot.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — support chat now greets + replies in premium voice; buttons use plain labels."
