#!/usr/bin/env bash
# stepB1gProbe.sh — READ ONLY. Why the phone doesn't pull B1G: is it in the stale list? does an M3U url resolve?
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
KEY=$(grep -E '^IPTV_INGEST_KEY=' .env 2>/dev/null | cut -d= -f2- | tr -d '"')

echo "== 1) Is B1G in the phone's stale list? (servers?stale=1) =="
curl -s "http://127.0.0.1:$PORT/internal/iptv/servers?key=$KEY&stale=1" | tr '}' '\n' | grep -iE "b1g|server" | head -20

echo; echo "== 2) B1G M3U url resolution (what the phone would fetch) =="
curl -s "http://127.0.0.1:$PORT/internal/iptv/url/SKU-00036?key=$KEY" | head -c 700; echo

echo; echo "== 3) B1G product + bot_sku confirm =="
cat > .b.js <<'JS'
require('/opt/gsz/node_modules/dotenv').config({ path: '/opt/gsz/.env' });
const { Pool } = require('/opt/gsz/node_modules/pg');
const p = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
(async () => {
  try {
    const r = await p.query("SELECT DISTINCT pp.bot_sku, pp.source, p.slug FROM products p JOIN product_plans pp ON pp.product_id=p.id WHERE p.slug ILIKE '%b1g%'");
    r.rows.forEach(x => console.log('  ' + JSON.stringify(x)));
  } catch (e) { console.log('  db err ' + e.message); }
  await p.end();
})();
JS
node .b.js; rm -f .b.js

echo; echo "== 4) recent B1G worker log lines (full) =="
grep -i "b1g" /root/.pm2/logs/gsz-iptv-worker-out.log 2>/dev/null | tail -6
echo DONE
