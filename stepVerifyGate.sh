#!/usr/bin/env bash
# stepVerifyGate.sh — Step 2: checkout requires a signed-in, WhatsApp-verified customer.
#   Patches routes/checkout.js (POST /checkout + POST /cart/place).
#   Admin toggle: wa_settings.require_wa_verify='off' turns the verify requirement off
#   (sign-in still required) — your safety valve if the WhatsApp bot is ever down.
#   Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CO=routes/checkout.js
cp -f "$CO" "$CO.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$CO.bak.$TS" "$CO"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch checkout.js"
node "$SRC/patch_verifygate.js" "$GSZ"
node --check "$CO" && echo "  checkout.js syntax ok"
echo "  gates present: $(grep -c 'VERIFY_GATE_v1 ' "$CO") (expect 2)"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — orders now require a signed-in, WhatsApp-verified account."
echo "      To temporarily allow unverified checkout (bot down): "
echo "      psql -c \"INSERT INTO wa_settings(key,value) VALUES('require_wa_verify','off') ON CONFLICT(key) DO UPDATE SET value='off';\""
echo "      Turn back on: set value='on'."
