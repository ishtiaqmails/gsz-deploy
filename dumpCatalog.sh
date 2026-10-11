#!/usr/bin/env bash
# dumpCatalog — the authoritative product route + schemas needed to wire the new model safely.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
PSQL(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "########## adminCatalog.js — all routes (map) ##########"
grep -nE "router\.(get|post)\(" routes/adminCatalog.js
echo
echo "########## adminCatalog.js — lines 1..175 (list + edit GET + save POST) ##########"
sed -n '1,175p' routes/adminCatalog.js
echo
echo "########## products table: all columns ##########"
PSQL -c "\d products" 2>&1 | sed -n '1,60p'
echo
echo "########## bot_products table: columns (for mapping + versions) ##########"
PSQL -c "\d bot_products" 2>&1 | sed -n '1,50p'
echo "== dumpCatalog done =="
