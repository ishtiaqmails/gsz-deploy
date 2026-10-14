#!/usr/bin/env bash
# stepEmailPremium.sh — premium per-type delivery email.
#   patch lib/emails.js (fieldsInner + per-type block + warranty; raw text fallback)
#   patch routes/checkout.js emailOrder (pass bot fields + admin How-to-Use/Warranty)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-emailprem-$TS"; cd "$GSZ"
EM=lib/emails.js; CO=routes/checkout.js
mkdir -p "$BK/lib" "$BK/routes"; cp "$GSZ/$EM" "$BK/$EM"; cp "$GSZ/$CO" "$BK/$CO"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$EM" "$GSZ/$EM"; cp "$BK/$CO" "$GSZ/$CO"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch emails.js + checkout.js"
node "$SRC/patch_email.js" "$GSZ"
node --check "$GSZ/$EM" && echo "   emails.js ok"
node --check "$GSZ/$CO" && echo "   checkout.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — delivery email now renders the per-type premium block (fields from bot, Warranty/How-to-Use from admin); raw text fallback"
