#!/usr/bin/env bash
# dumpAccount — map the customer account area: routes, views, session shape, data tables.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "## route files ##"
ls routes/ 2>/dev/null

echo "## account/customer views ##"
ls views/ 2>/dev/null | grep -iE 'account|customer|dash|login|signup|profile|wallet|ticket' || echo "(none matched)"

echo "## account layout/shell views ##"
ls views/ 2>/dev/null | grep -iE 'shell|layout|header|_' | head -20

echo "## every /account route (file:line path) ##"
grep -rnoE "router\.(get|post)\(['\"][^'\"]+['\"]" routes/ 2>/dev/null | grep -iE "account|dashboard|orders|products|wallet|ticket|profile|login|logout|signup|register" | head -60

echo "## where req.session.customer is set/shaped (login) ##"
grep -rnoE "req\.session\.customer *= *\{[^}]*\}" routes/ 2>/dev/null | head -8
grep -rnE "session\.customer" routes/*.js 2>/dev/null | grep -iE "id:|email:|wa_number:|name:|ref_code:|=" | head -12

echo "## relevant tables present ##"
Q -tAc "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'customer|wallet|ticket|subscription|notification|payment_method|issue|cart|token' ORDER BY 1" 2>&1

echo "## customers columns ##"
Q -tAc "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='customers'" 2>&1

echo "## do wallet / tickets exist? (expect errors if not) ##"
for t in wallet wallets wallet_transactions support_tickets tickets notifications; do
  echo -n "$t: "; Q -tAc "SELECT count(*) FROM $t" 2>&1 | head -1
done

echo "## order_issues columns (current 'tickets') ##"
Q -tAc "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='order_issues'" 2>&1
echo "== dumpAccount done =="
