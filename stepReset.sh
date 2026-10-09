#!/usr/bin/env bash
# stepReset — ZERO OUT test/transactional data for a clean test.
# Backs up first, then truncates ONLY test tables. Catalog/config untouched.
set -Eeuo pipefail
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "== fresh pre-reset backup =="
mkdir -p /root/gsz-backups
BK="/root/gsz-backups/gsz-prereset-$(date +%Y%m%d-%H%M%S).sql.gz"
pg_dump -h "${DBH:-localhost}" -U "$DBU" "$DBN" | gzip > "$BK"
echo "backup OK: $BK ($(du -h "$BK" | cut -f1))"

echo "== zeroing test data =="
Q -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
TRUNCATE orders, order_issues, customers, customer_carts, customer_tokens,
         customer_whatsapp_links, whatsapp_identities, whatsapp_verification_sessions,
         trial_claims, restock_waitlist, wa_audit_log, nf_assignments, user_sessions, cs_events
  RESTART IDENTITY CASCADE;
UPDATE cs_posts SET views = 0;
COMMIT;
SQL

echo "== verify WIPED (should all be 0) =="
Q -c "SELECT 'orders' AS t, count(*) FROM orders
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'trial_claims', count(*) FROM trial_claims
UNION ALL SELECT 'wa_links', count(*) FROM customer_whatsapp_links
UNION ALL SELECT 'wa_identities', count(*) FROM whatsapp_identities
UNION ALL SELECT 'wa_audit_log', count(*) FROM wa_audit_log
UNION ALL SELECT 'restock_waitlist', count(*) FROM restock_waitlist
UNION ALL SELECT 'order_issues', count(*) FROM order_issues
UNION ALL SELECT 'cs_events', count(*) FROM cs_events ORDER BY t"

echo "== verify KEPT (catalog/config intact) =="
Q -c "SELECT 'products' AS t, count(*) FROM products
UNION ALL SELECT 'product_plans', count(*) FROM product_plans
UNION ALL SELECT 'categories', count(*) FROM categories
UNION ALL SELECT 'payment_methods', count(*) FROM payment_methods
UNION ALL SELECT 'trial_servers', count(*) FROM trial_servers
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'coupons', count(*) FROM coupons ORDER BY t"

cd "$GSZ"; pm2 restart gsz --update-env >/dev/null
echo "== reset done — fresh database, ready to test =="
