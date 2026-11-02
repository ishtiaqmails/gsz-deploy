#!/usr/bin/env bash
# stepPhoneB1gDiag.sh — READ ONLY. How the phone agent/runner is served + B1G last-pull diagnosis.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || { echo "no $GSZ"; exit 1; }

echo "===== 1) IPTV ingest/agent routes (routes/iptv.js) ====="
grep -nE "agent|/internal/iptv|ingest|INGEST|gsz-run|termux|boot|wake|while|sleep 43200|getM3U|push" routes/iptv.js 2>/dev/null | head -40

echo; echo "===== 2) served agent/runner script body ====="
AL=$(grep -n "agent.sh\|agent\\.sh\|/agent" routes/iptv.js 2>/dev/null | head -1 | cut -d: -f1)
echo "agent route near line: ${AL:-?}"
[ -n "${AL:-}" ] && sed -n "${AL},$((AL+75))p" routes/iptv.js

echo; echo "===== 3) any agent script file on disk ====="
ls -1 lib/iptv/ scripts/ 2>/dev/null | grep -iE "agent|run|termux|boot" || echo "(none by name)"
grep -rln "termux-wake-lock\|.termux/boot\|get.php\|player_api" lib/iptv/*.js scripts/*.sh 2>/dev/null | head

echo; echo "===== 4) B1G — recent worker results + product/plan ====="
grep -i "b1g" /root/.pm2/logs/gsz-iptv-worker-out.log 2>/dev/null | tail -10
cat > .q.js <<'JS'
require('/opt/gsz/node_modules/dotenv').config({ path: '/opt/gsz/.env' });
const { Pool } = require('/opt/gsz/node_modules/pg');
const p = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
(async () => {
  try {
    const r = await p.query("SELECT p.slug, p.name, pp.bot_sku, pp.source FROM products p JOIN product_plans pp ON pp.product_id=p.id WHERE p.slug ILIKE '%b1g%' OR p.name ILIKE '%b1g%' LIMIT 10");
    console.log('product/plans:'); r.rows.forEach(x => console.log('  ' + JSON.stringify(x)));
    const l = await p.query("SELECT server_key, live_count, vod_count, series_count, status, updated_at FROM iptv_library WHERE server_key ILIKE '%b1g%'");
    console.log('library:'); l.rows.forEach(x => console.log('  ' + JSON.stringify(x)));
  } catch (e) { console.log('db err: ' + e.message); }
  await p.end();
})();
JS
node .q.js 2>&1 | head -25; rm -f .q.js
echo DONE
