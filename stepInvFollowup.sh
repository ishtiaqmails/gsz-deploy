#!/usr/bin/env bash
# stepInvFollowup.sh — inventory/stock follow-up uses the same deliveryMsg.compose().followup
# as bot orders (one layout). Also prefers the plan's delivery_instructions.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-invfollowup-$TS"; cd "$GSZ"
DV=lib/deliver.js
mkdir -p "$BK/lib"; cp "$GSZ/$DV" "$BK/$DV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$DV" "$GSZ/$DV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch deliver.js"
node "$SRC/patch_invfollowup.js" "$GSZ"
node --check "$GSZ/$DV" && echo "   deliver.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — inventory follow-up now matches the bot-order follow-up exactly (same composer)."
