#!/usr/bin/env bash
# dumpInv — inventory/stock model + how low-stock is computed (for dashboard panel + inventory section).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "$1" 2>&1; }
QT(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tc "$1" 2>&1; }

echo "########## inventory_items ##########"; Q "\d inventory_items" | sed -n '1,40p'
echo "--- counts by status/state ---"; QT "SELECT column_name FROM information_schema.columns WHERE table_name='inventory_items' ORDER BY ordinal_position"
echo
echo "########## product_plans (stock link) ##########"; Q "\d product_plans" | sed -n '1,40p'
echo
echo "########## restock_waitlist ##########"; Q "\d restock_waitlist" | sed -n '1,25p'
echo "--- waitlist count ---"; QT "SELECT count(*) FROM restock_waitlist"
echo
echo "########## how inventory page computes stock (routes/adminInventory.js) ##########"
grep -nE "SELECT|FROM inventory|stock|available|COUNT|count\(|low|group by|GROUP BY|render\(" routes/adminInventory.js | head -60
echo
echo "########## inventory list GET handler (first ~90 lines) ##########"
sed -n '1,90p' routes/adminInventory.js
echo "== dumpInv done =="
