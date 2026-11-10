#!/usr/bin/env bash
# recon5 : READ-ONLY. Shows exactly how the homepage computed the live-incrementing
# "orders delivered" number, so the top strip can reproduce it. Changes nothing.
cd /opt/gsz

echo "=== home.ejs lines 56-92 (deliveredNum / rating logic) ==="
sed -n '56,92p' views/home.ejs

echo; echo "=== home route file(s) ==="
grep -rln "views/home\|render('home'\|render(\"home" routes --include=*.js | grep -vi "\.bak"

echo; echo "=== how deliveredNum / order count is passed into home ==="
grep -rn "deliveredNum\|ordersCount\|orderCount\|delivered:" routes --include=*.js | grep -vi "\.bak" | head -15

echo; echo "=== any orders-count query (to reproduce the live number) ==="
grep -rn "COUNT(\*).*orders\|FROM orders\|orders_count\|delivered" routes/*.js lib/*.js | grep -vi "\.bak" | head -15
echo "=== recon5 done ==="
