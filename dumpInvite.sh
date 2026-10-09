#!/usr/bin/env bash
# dumpInvite — did the invite order reach the bot? + the vendor_invite fulfillment branch. COMPACT.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "## recent orders — source/sku/type/status + reached-bot? ##"
Q -c "SELECT order_no, left(product_name,20) AS product, source, bot_sku, bot_type, status, (bot_order_id IS NOT NULL) AS at_bot, created_at::timestamp(0) FROM orders ORDER BY id DESC LIMIT 8" 2>&1

echo "## the invite product's plan config (source=bot? has bot_sku?) ##"
Q -c "SELECT pp.bot_sku, pp.source, pp.bot_type, bp.delivery_type FROM product_plans pp LEFT JOIN bot_products bp ON bp.sku=pp.bot_sku WHERE bp.delivery_type='vendor_invite' OR pp.bot_type ILIKE '%invite%' LIMIT 6" 2>&1

echo "## single-order fulfilment branch (300-368) ##"
sed -n '300,368p' routes/checkout.js
echo "== dumpInvite done =="
