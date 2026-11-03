GSZ=/opt/gsz; cd $GSZ
echo "== worker pool init (1-28) =="
sed -n '1,28p' lib/iptv/worker.js
echo "== summary.json route =="
L=$(grep -n "summary.json\|/summary'" routes/iptv.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "$((L-2)),$((L+48))p" routes/iptv.js
echo "== intel + classify full (28-72) =="
sed -n '28,72p' routes/adminIptv.js
echo "== categories construction in lib/iptv =="
grep -rn "categories" lib/iptv/*.js | head -30
echo "== product.ejs price+plans (200-235) =="
sed -n '200,235p' views/product.ejs
echo "== product.ejs tabs + whats-inside (340-380) =="
sed -n '340,380p' views/product.ejs
echo "== product.ejs wi tiles js (556-578) =="
sed -n '556,578p' views/product.ejs
echo DONE
