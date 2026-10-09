#!/usr/bin/env bash
# dumpReset — SAFE preflight for the test-data reset: full backup + row counts.
# NO data is deleted here.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "########## 1. full backup (reversible safety) ##########"
mkdir -p /root/gsz-backups
BK="/root/gsz-backups/gsz-$(date +%Y%m%d-%H%M%S).sql.gz"
if pg_dump -h "${DBH:-localhost}" -U "$DBU" "$DBN" | gzip > "$BK"; then
  echo "backup OK: $BK  ($(du -h "$BK" | cut -f1))"
else
  echo "!! BACKUP FAILED — do NOT run the reset until this works"
fi
echo
echo "########## 2. current row counts (approx, all tables) ##########"
Q -c "SELECT relname AS table_name, n_live_tup AS approx_rows FROM pg_stat_user_tables ORDER BY relname"
echo
echo "########## 3. exact counts for the WIPE tables ##########"
for t in orders order_issues customers customer_carts customer_tokens customer_whatsapp_links whatsapp_identities whatsapp_verification_sessions trial_claims restock_waitlist wa_audit_log nf_assignments user_sessions; do
  c=$(Q -tAc "SELECT count(*) FROM $t" 2>/dev/null); echo "  $t = ${c:-'(no such table)'}"
done
echo
echo "########## 4. inventory status breakdown (what will reset to available) ##########"
Q -c "SELECT status, count(*) FROM inventory_items GROUP BY status ORDER BY 2 DESC" 2>/dev/null
echo "== dumpReset done =="
