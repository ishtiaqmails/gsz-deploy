#!/usr/bin/env bash
# dumpAmInv — compact diagnosis for (A) store contact number source, (B) invite vendor-notify path.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "########## A1. store/contact/support/whatsapp number settings ##########"
Q -c "SELECT key, left(value,48) AS value FROM wa_settings WHERE key ~* 'number|contact|support|whatsapp|store|phone|wa_' ORDER BY key" 2>&1 | head -40

echo "########## A2. other settings tables that may hold a store phone ##########"
Q -tAc "SELECT table_name FROM information_schema.tables WHERE table_name ~* 'setting|config|store|site'" 2>&1 | head
for t in site_settings store_settings settings; do
  Q -c "SELECT key, left(value,48) FROM $t WHERE key ~* 'number|contact|support|whatsapp|phone'" 2>&1 | head -12
done

echo "########## B1. invite/vendor submit + notify path in checkout.js ##########"
grep -nE "vendor_invite|invite|vendor|Payment Received|payment.?received|confirmation|submitOrder|submit-order|notify|storeContact|supportNumber|store_number" routes/checkout.js | head -50

echo "########## B2. how non-polling (manual/invite) types are handled (grep for short-circuit) ##########"
grep -nE "deliveryType|delivery_type|bot_type|=== *'vendor|=== *'invite|includes\(|manual|instant" routes/checkout.js | head -40

echo "########## B3. recent orders — type/ref/status (did invite reach bot?) ##########"
Q -c "SELECT order_no, left(product_name,22) AS product, bot_type, delivery_type, status, (bot_ref IS NOT NULL) AS sent_to_bot, left(coalesce(bot_ref,''),24) AS ref, created_at::timestamp(0) FROM orders ORDER BY id DESC LIMIT 10" 2>&1

echo "########## B4. orders table columns (so we know real column names) ##########"
Q -tAc "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='orders'" 2>&1
echo "== dumpAmInv done =="
