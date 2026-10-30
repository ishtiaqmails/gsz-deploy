#!/usr/bin/env bash
# stepCurrency4.sh — display default = USD for all non-PK visitors (local currency stays in the
#   picker); buffer no longer shaves the owner-set USD/PKR base prices. Patches public/js/app.js.
# Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
F=public/js/app.js
cp -f "$GSZ/$F" "$GSZ/$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_currency4.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/$F" && echo "  app.js ok"
grep -q "var want=(ctry==='PK')?'PKR':(ctry?'USD':" "$GSZ/$F" && echo "  default-rule present"
test "$(grep -c 'function _conv' "$GSZ/$F")" = "1" && echo "  _conv single (no duplication)"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "DONE — non-PK visitors now default to USD; they can switch to their local currency from the"
echo "picker. PK stays PKR; unknown location (CF header off) stays PKR (safe for your home market)."
