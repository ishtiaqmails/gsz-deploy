#!/usr/bin/env bash
# dumpDash — data + current code for the /admin dashboard rebuild (command center).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "$1" 2>&1; }
QT(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tc "$1" 2>&1; }

echo "########## 1. current dashboard handler (routes/admin.js) ##########"
grep -n "dashboard" routes/admin.js | head
sed -n '43,50p' routes/admin.js
echo "--- views/admin/dashboard.ejs ---"; cat views/admin/dashboard.ejs
echo
echo "########## 2. all public tables ##########"
QT "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename"
echo
echo "########## 3. orders schema ##########"
Q "\d orders" | sed -n '1,45p'
echo "--- order status distribution ---"; QT "SELECT status, count(*) FROM orders GROUP BY status ORDER BY 2 DESC"
echo "--- orders: total, today, this month ---"
QT "SELECT count(*) total, count(*) FILTER (WHERE created_at::date=current_date) today, count(*) FILTER (WHERE date_trunc('month',created_at)=date_trunc('month',now())) this_month FROM orders"
echo
echo "########## 4. revenue (find the amount + paid columns) ##########"
Q "\d orders" | grep -iE "amount|total|price|paid|pkr|status|created"
echo "--- try revenue sums (adjust col if needed) ---"
QT "SELECT column_name,data_type FROM information_schema.columns WHERE table_name='orders' AND (column_name ~* 'amount|total|price|pkr|paid') ORDER BY 1"
echo
echo "########## 5. payments schema + sums ##########"
Q "\d payments" | sed -n '1,40p'
echo
echo "########## 6. customers / accounts ##########"
QT "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename ~* 'customer|account|user|subscriber' ORDER BY 1"
for t in customers accounts users customer_accounts; do
  echo "--- \d $t ---"; Q "\d $t" 2>/dev/null | sed -n '1,20p'
done
echo
echo "########## 7. inventory / stock (low stock source) ##########"
QT "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename ~* 'stock|invent|plan|pool' ORDER BY 1"
Q "\d product_plans" 2>/dev/null | grep -iE "stock|qty|quantity|available|count"
echo
echo "########## 8. recent orders sample (shape) ##########"
QT "SELECT * FROM orders ORDER BY created_at DESC LIMIT 2"
echo "== dumpDash done =="
