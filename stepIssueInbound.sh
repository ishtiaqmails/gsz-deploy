#!/usr/bin/env bash
# #77 Stage C — inbound WhatsApp replies land in the issue thread.
# Patches routes/whatsapp.js (/internal/whatsapp/incoming). GSZ-side only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-issueinbound-$TS"; cd "$GSZ"
W=routes/whatsapp.js
mkdir -p "$BK/$(dirname "$W")"; cp "$GSZ/$W" "$BK/$W"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$W" "$GSZ/$W"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_issueinbound.js" "$GSZ"
node --check "$GSZ/$W" && echo "   whatsapp.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — a customer's WhatsApp reply now lands in their open issue thread."
