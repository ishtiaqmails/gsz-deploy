#!/usr/bin/env bash
# stepProductUsd.sh — Stage 3c: public product page carries price_usd so a SET dollar price shows
#   on the product pills exactly as charged (blank still converts PKR). Patches routes/products.js.
# Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
F=routes/products.js
cp -f "$GSZ/$F" "$GSZ/$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
echo "==> patch"; node "$SRC/patch_product_usd.js" "$GSZ"
echo "==> validate"; node --check "$GSZ/$F" && echo "  products.js ok"
grep -q "price_usd: Number(r.price_usd || 0)," "$GSZ/$F" && echo "  plan map carries price_usd"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo; echo "DONE — product page now shows your set \$ price identically to checkout. Display=charge everywhere."
