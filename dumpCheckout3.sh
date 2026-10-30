#!/usr/bin/env bash
# dumpCheckout3.sh — read-only. Exactly how checkout works today so Stage 3 wires the 2 rails
# (PKR via Meezan/Nayapay, USD via Binance) cleanly. Small + targeted.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) checkout files (routes/views/js that mention checkout/payment/order) ###"
grep -rlnE "checkout|REGIONS|binance|meezan|nayapay|payment_method|pay_method" \
  "$GSZ"/routes "$GSZ"/views "$GSZ"/public/js "$GSZ"/lib "$GSZ"/server.js 2>/dev/null | grep -v node_modules | head -25

echo
echo "### B) REGIONS / currency / amount math in checkout.js ###"
F=$(ls "$GSZ"/public/js/checkout.js 2>/dev/null || true)
[ -n "$F" ] && grep -nE "REGIONS|cur:|rate:|region\(|amount|total|price|usd|pkr" "$F" | head -30 || echo "(no public/js/checkout.js)"

echo
echo "### C) payment methods as shown to the customer (Meezan/Nayapay/Binance names + account details) ###"
grep -rnE "Meezan|Nayapay|Binance|IBAN|account|wallet|TRC20|BEP20|USDT|bank" \
  "$GSZ"/views "$GSZ"/routes "$GSZ"/lib 2>/dev/null | grep -viE "node_modules|accountKey|//|account_sid" | head -25

echo
echo "### D) where payment account details live (settings table or config) ###"
grep -rnE "wa_settings|settings|payment|pay_|account_title|account_number|binance_|usdt_" \
  "$GSZ"/routes "$GSZ"/lib "$GSZ"/server.js 2>/dev/null | grep -iE "settings|payment|account|binance|usdt|meezan|nayapay" | grep -v node_modules | head -20

echo
echo "### E) orders table — currency/amount/method columns ###"
grep -rnE "INSERT INTO orders|orders *\(|amount|currency|cur\b|pay_method|payment_method|total_pkr|total_usd|price" \
  "$GSZ"/routes "$GSZ"/lib 2>/dev/null | grep -iE "insert into orders|currency|amount|pay_method|payment_method|total_" | grep -v node_modules | head -20

echo
echo "### F) orders schema (DB columns) ###"
cat > /tmp/_ordcols.js <<'JS'
const {Pool}=require('pg');const E=process.env;
const pool=E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):((E.DB_HOST||E.DB_NAME)?new Pool({host:E.DB_HOST,port:E.DB_PORT||5432,user:E.DB_USER,password:E.DB_PASSWORD,database:E.DB_NAME}):new Pool());
(async()=>{try{const r=await pool.query("select column_name,data_type from information_schema.columns where table_name='orders' order by ordinal_position");console.log(r.rows.map(x=>x.column_name+':'+x.data_type).join('\n'));}catch(e){console.log('ERR',e.message);}process.exit(0);})();
JS
( set -a; [ -f "$GSZ/.env" ] && . "$GSZ/.env"; set +a; node /tmp/_ordcols.js 2>&1 | head -40 )
echo "== END =="
