#!/usr/bin/env bash
# dumpSchema — columns for products / product_plans / bot_products / order_issues (wire My Orders + foundations). SMALL.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }
for t in products product_plans bot_products order_issues; do
  echo "## $t ##"; Q -tAc "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='$t'" 2>&1
done
echo "## warranty/duration/renew-ish fields anywhere ##"
Q -tAc "SELECT table_name||'.'||column_name FROM information_schema.columns WHERE column_name ~* 'warrant|duration|renew|expire|days|period' ORDER BY 1" 2>&1 | head -20
echo "== dumpSchema done =="
