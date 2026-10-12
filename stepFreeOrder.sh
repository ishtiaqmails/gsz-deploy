#!/usr/bin/env bash
# #81 — 100%-off coupon skips checkout (single-product). A coupon that zeroes the total
# needs no payment method or proof: the order is created 'paid' and fulfilled directly.
# Also adds live coupon validation + a "Place free order" UI to the checkout popup.
#   PATCHED: routes/checkout.js (free path on /checkout + free flag on /api/coupon/validate)
#   VIEW:    views/partials/checkout_model.ejs (live coupon check + free branch)
# REQUIRES #80 (stepCouponScope.sh) already deployed.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-free-$TS"; cd "$GSZ"
C=routes/checkout.js; V=views/partials/checkout_model.ejs
for f in "$C" "$V"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring (if this failed on an anchor miss, deploy stepCouponScope.sh first)"; for f in "$C" "$V"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_freeorder.js" "$GSZ"
cp -f "$SRC/checkout_model.ejs" "$GSZ/$V"
node --check "$GSZ/$C" && echo "   checkout.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$V','utf8'),{filename:'$GSZ/$V'});console.log('   checkout_model.ejs ok')"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — 100%-off coupons skip payment: free order created paid + fulfilled directly."
