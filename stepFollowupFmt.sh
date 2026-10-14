#!/usr/bin/env bash
# stepFollowupFmt.sh — cleaner Instructions & Warranty follow-up (bullets straight under header,
# Warranty inline). Updates lib/deliveryMsg.js (composed follow-up used by bot-order delivery).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-followup-$TS"; cd "$GSZ"
DM=lib/deliveryMsg.js
mkdir -p "$BK/lib"; cp "$GSZ/$DM" "$BK/$DM"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$DM" "$GSZ/$DM"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install deliveryMsg.js"
cp "$SRC/deliveryMsg.js" "$GSZ/$DM"
node --check "$GSZ/$DM" && echo "   deliveryMsg.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Instructions & Warranty follow-up uses the clean layout (no 'How to use' label, inline Warranty)."
