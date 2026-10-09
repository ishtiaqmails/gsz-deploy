#!/usr/bin/env bash
# dumpCheckout — bot-order delivery flow (poll + message building) for amember/invite diagnosis.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## delivery / status keywords in checkout.js ##########"
grep -nE "amember|invite|vendor|delivery_type|Preparing|preparing|delivering|delivered_credentials|order-status|orderStatus|submitOrder|submit-order|buildDelivery|formatted|deliverMsg|sendMessage|message" routes/checkout.js | head -70
echo
echo "########## pollOnce + surrounding flow (lines 400-540) ##########"
sed -n '400,540p' routes/checkout.js
echo
echo "########## how delivery message is built for bot orders (grep wider) ##########"
grep -rnE "Preparing|preparing your order|is being prepared|invite|vendor_invite|amember" routes/ views/ lib/ 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -40
echo
echo "########## recent bot orders + their status/creds (read-only) ##########"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "SELECT order_no, product_name, bot_type, status, left(coalesce(delivered_credentials,''),80) AS cred, created_at::timestamp(0) FROM orders ORDER BY id DESC LIMIT 10" 2>&1
echo "== dumpCheckout done =="
