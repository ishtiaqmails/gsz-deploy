#!/usr/bin/env bash
# step86-dump — READ-ONLY. Shows checkout.js requires, the notifyOrder function,
# its call sites, and how credentials are stored, so I can hook customer
# WhatsApp notifications in one place. Changes nothing.
set -euo pipefail
APP=/opt/gsz
cd "$APP"

echo "========== checkout.js: top requires (lines 1-30) =========="
sed -n '1,30p' routes/checkout.js

echo
echo "========== notifyOrder definition (+40 lines) =========="
grep -n -A40 "function notifyOrder" routes/checkout.js || echo "(notifyOrder not found)"

echo
echo "========== notifyOrder / emailOrder call sites =========="
grep -nE "notifyOrder\(|emailOrder\(" routes/checkout.js || true

echo
echo "========== credential + delivery fields usage =========="
grep -nE "delivered_credentials|claim_result|delivered_at|verified_at|startStatus|order_no" routes/checkout.js | head -40

echo
echo "========== order.ejs: does it show credentials? =========="
grep -nE "delivered_credentials|credential|order_no|status" views/order.ejs | head -30

echo
echo "==> step86-dump done (read-only)"
