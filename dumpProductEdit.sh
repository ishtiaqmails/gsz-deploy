#!/usr/bin/env bash
# dumpProductEdit — the product editor view + the products table schema (for premium rebuild).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## products table schema ##########"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "\d products" 2>&1 | sed -n '1,45p'
echo
echo "########## views/admin/product_edit.ejs (full) ##########"
cat views/admin/product_edit.ejs
echo "== dumpProductEdit done =="
