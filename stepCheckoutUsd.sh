#!/usr/bin/env bash
# stepCheckoutUsd.sh — Stage 3a: single-product checkout charges the owner-set price_usd on the
#   USD/Binance rail (live-rate fallback when blank), replacing the hardcoded pkr*0.0036.
#   Display, charge, and recorded amount_usd all agree. Cart = Stage 3b. Patches routes/checkout.js.
# Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
F=routes/checkout.js
cp -f "$GSZ/$F" "$GSZ/$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_checkout_usd.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/$F" && echo "  checkout.js ok"
node --check "$GSZ/lib/gsz_pricing.js" && echo "  gsz_pricing.js ok (engine reachable)"
grep -q "async function usdAmt(pkr, priceUsd)" "$GSZ/$F" && echo "  usdAmt helper present"
test "$(grep -c 'const usd = await usdAmt(pkr, plan.price_usd);' "$GSZ/$F")" = "2" && echo "  GET+POST USD from price_usd"
grep -q "const usdv = await usdAmt(" "$GSZ/$F" && echo "  recorded amount_usd from price_usd"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "DONE — single-product checkout now charges your set \$ price on Binance (live-rate fallback"
echo "when a plan's USD is blank). Fill price_usd on your plans so Binance shows real prices."
echo "Cart checkout is unchanged (Stage 3b next)."
