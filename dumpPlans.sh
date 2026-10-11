#!/usr/bin/env bash
# dumpPlans — everything needed to wire a per-plan "Most Popular" flag:
#   1) the plan table name + schema
#   2) how adminCatalog.js reads/saves plan rows (to add plan_popular)
#   3) where the public product page builds its `plans` array (to pass `popular` through)
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
PSQL(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }
echo "########## tables containing 'plan' ##########"
PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ILIKE '%plan%';" 2>&1
echo "########## schema of each plan-ish table ##########"
for t in $(PSQL -tAc "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ILIKE '%plan%';" 2>/dev/null); do echo "=== \\d $t ==="; PSQL -c "\\d $t" 2>&1 | sed -n '1,40p'; done
echo
echo "########## adminCatalog.js — plan read/save (plan_label/plan_price/INSERT/UPDATE) ##########"
grep -nE "plan_label|plan_price|plan_old|plan_id|plan_from|plan_until|plan_warranty|INTO .*plan|UPDATE .*plan|DELETE .*plan|plans?\b" routes/adminCatalog.js 2>&1 | head -80
echo
echo "########## public product render — where `plans` is built ##########"
grep -rnE "render\('product'|res\.render\(\"product\"|price_pkr|old_pkr|FROM .*plan" routes/*.js 2>&1 | grep -iE "product|plan|price_pkr" | head -40
echo "== dumpPlans done =="
