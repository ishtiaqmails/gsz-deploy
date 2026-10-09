#!/usr/bin/env bash
# dumpOrderNo — how order_no is generated + current sequence state. COMPACT.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "## order_no generation sites ##"
grep -rnE "order_no *=|'GSZ-|\"GSZ-|GSZ-'|nextval|order_no_seq|generateOrderNo|makeOrderNo|order_no:" routes/ lib/ 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -25
echo
echo "## orders id sequence + max order_no ##"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "SELECT last_value FROM orders_id_seq" 2>&1 | head -4
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "SELECT max(order_no) AS max_no, count(*) AS n FROM orders" 2>&1 | head -4
echo "== dumpOrderNo done =="
