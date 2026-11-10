#!/usr/bin/env bash
# gsz-sweep22 : DIAGNOSTIC. Temporarily logs the order-query creds + result/error
# from inside the running app, triggers a render, prints the log, then restores
# the clean engine. Reveals why the in-app count query fails.
set -e
cd /opt/gsz
cp lib/socialcounts.js /opt/gsz/.gsz-s22-sc.bak
rm -f /opt/gsz/.gsz-ord-debug.log

cat > /tmp/s22log.js <<'JS'
const fs=require('fs'); const f='lib/socialcounts.js'; let s=fs.readFileSync(f,'utf8');
s=s.replace("ord = { n: (r.rows[0] && r.rows[0].n) || 0, t: Date.now() };",
  "ord = { n: (r.rows[0] && r.rows[0].n) || 0, t: Date.now() }; try{fs.appendFileSync('/opt/gsz/.gsz-ord-debug.log','OK n='+ord.n+'\\n')}catch(x){}");
s=s.replace(".catch(function(){}).finally(function(){ ordBusy = false; });",
  ".catch(function(e){ try{fs.appendFileSync('/opt/gsz/.gsz-ord-debug.log','query-err '+e.message+'\\n')}catch(x){} }).finally(function(){ ordBusy = false; });");
s=s.replace("const { Pool } = require('pg');\n    pool = new Pool",
  "try{fs.appendFileSync('/opt/gsz/.gsz-ord-debug.log','creds host='+pick('DB_HOST')+' db='+pick('DB_NAME')+' user='+pick('DB_USER')+' port='+pick('DB_PORT')+' hasPass='+(!!pick('DB_PASS'))+'\\n')}catch(x){}\n    const { Pool } = require('pg');\n    pool = new Pool");
fs.writeFileSync(f,s); console.log('logging added');
JS
node /tmp/s22log.js
node --check lib/socialcounts.js || { echo "syntax error — reverting"; cp /opt/gsz/.gsz-s22-sc.bak lib/socialcounts.js; exit 1; }

pm2 restart gsz
sleep 2

echo "=== node listen ports ==="
ss -ltnp 2>/dev/null | grep -iE 'node' | grep -oE 'LISTEN.*:[0-9]+' | grep -oE ':[0-9]+' | sort -u | head
echo "=== trigger a render (so in-app refreshOrders runs) ==="
for P in 3900 3600 3001 3000 8080; do curl -s -m 4 "http://127.0.0.1:$P/product/nord-vpn" -o /dev/null -w "port $P -> %{http_code}\n" 2>/dev/null; done
sleep 4

echo "=== order-query debug log (from inside the app) ==="
cat /opt/gsz/.gsz-ord-debug.log 2>/dev/null || echo "(no log written — refreshOrders never ran)"

echo "=== restoring clean engine ==="
cp /opt/gsz/.gsz-s22-sc.bak lib/socialcounts.js
pm2 restart gsz
echo "DONE: diagnostic complete, clean engine restored."
