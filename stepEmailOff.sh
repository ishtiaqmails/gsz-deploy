#!/usr/bin/env bash
# stepEmailOff.sh — disable the payment-confirmed / order-received email entirely.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-emailoff-$TS"; cd "$GSZ"
CO=routes/checkout.js
mkdir -p "$BK/routes"; cp "$GSZ/$CO" "$BK/$CO"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$CO" "$GSZ/$CO"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch checkout.js (emailOrder: skip 'confirm')"
node "$SRC/patch_emailoff.js" "$GSZ"
node --check "$GSZ/$CO" && echo "   checkout.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — payment-confirmed email is OFF. Customers only get the final 'order ready' email."
