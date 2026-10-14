#!/usr/bin/env bash
# stepTrialPremium.sh — mask trial delivery in our premium per-type format.
#   lib/deliveryMsg.js  -> adds trial header/footer (opts.trial); order delivery unchanged
#   lib/trialpoll.js    -> routes trial delivery through deliveryMsg.compose when fields present
#                          (falls back to whatsapp.trial_ready template otherwise)
# Full-file copies from libsrc (no fragile anchors). Restart also makes the new lifecycle
# templates live (flushes any in-memory template cache).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-trialprem-$TS"; cd "$GSZ"
DM=lib/deliveryMsg.js; TP=lib/trialpoll.js
mkdir -p "$BK/lib"; cp "$GSZ/$DM" "$BK/$DM"; cp "$GSZ/$TP" "$BK/$TP"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$DM" "$GSZ/$DM"; cp "$BK/$TP" "$GSZ/$TP"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install deliveryMsg.js + trialpoll.js"
cp "$SRC/deliveryMsg.js" "$GSZ/$DM"
cp "$SRC/trialpoll.js"   "$GSZ/$TP"
node --check "$GSZ/$DM" && echo "   deliveryMsg.js ok"
node --check "$GSZ/$TP" && echo "   trialpoll.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — trial delivery now masked premium when the bot sends structured fields; template fallback otherwise."
echo "       (lifecycle templates are now live too — restart flushed the template cache.)"
