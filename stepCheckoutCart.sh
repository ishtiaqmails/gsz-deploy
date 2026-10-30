#!/usr/bin/env bash
# stepCheckoutCart.sh — Stage 3b: CART checkout USD = sum of each line's owner-set price_usd
#   (live-rate fallback per line when blank), replacing the hardcoded total*0.0036. Depends on
#   Stage 3a's usdAmt(). Display, selection, and recorded amount_usd all agree. Patches checkout.js.
# Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
F=routes/checkout.js
if ! grep -q "async function usdAmt(pkr, priceUsd)" "$GSZ/$F"; then
  echo "!! Stage 3a (usdAmt helper) not found — run stepCheckoutUsd.sh first."; exit 1
fi
cp -f "$GSZ/$F" "$GSZ/$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_checkout_cart.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/$F" && echo "  checkout.js ok"
grep -q "async function cartUsd(lines)" "$GSZ/$F" && echo "  cartUsd helper present"
test "$(grep -c 'total \* REGIONS.US.rate' "$GSZ/$F")" = "0" && echo "  no hardcoded cart USD left"
grep -q "const usdTotal = +((await cartUsd(lines))" "$GSZ/$F" && echo "  recorded cart amount_usd from price_usd"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "DONE — cart checkout now charges the sum of each item's set \$ price on Binance (live-rate"
echo "fallback per line when blank). Both single-product and cart are now currency-correct."
