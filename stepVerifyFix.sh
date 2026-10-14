#!/usr/bin/env bash
# stepVerifyFix.sh — fix the verification flow:
#   - no verification code sent to the customer's WhatsApp (WhatsApp verifies via messaging the bot)
#   - no email code on signup; email verification sends only when the customer clicks Verify email
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-verifyfix-$TS"; cd "$GSZ"
AC=routes/account.js
mkdir -p "$BK/routes"; cp "$GSZ/$AC" "$BK/$AC"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AC" "$GSZ/$AC"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch account.js"
node "$SRC/patch_verifyfix.js" "$GSZ"
node --check "$GSZ/$AC" && echo "   account.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — signup sends nothing; email verifies only on Verify-email click; WhatsApp verifies only by messaging the bot."
