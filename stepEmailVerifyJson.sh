#!/usr/bin/env bash
# stepEmailVerifyJson.sh — /account/tools/email/verify reads the JSON body (hub posts JSON).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-evjson-$TS"; cd "$GSZ"
AC=routes/account.js
mkdir -p "$BK/routes"; cp "$GSZ/$AC" "$BK/$AC"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AC" "$GSZ/$AC"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch account.js"
node "$SRC/patch_emailverifyjson.js" "$GSZ"
node --check "$GSZ/$AC" && echo "   account.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — email code verification now reads the JSON body; a correct code verifies."
