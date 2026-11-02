#!/usr/bin/env bash
# stepMsgLibDiag.sh — READ ONLY. Collect every bot message (owner cmds + customer replies + DB templates) + IPTV library status.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || { echo "no $GSZ"; exit 1; }

echo "===== 1) ownerCommand — full (help + stock/orders/order/addstock/find/plans/sell/menu) ====="
L=$(grep -n "async function ownerCommand" routes/whatsapp.js | head -1 | cut -d: -f1)
echo "ownerCommand at line ${L:-?}"
[ -n "${L:-}" ] && sed -n "${L},$((L+95))p" routes/whatsapp.js

echo; echo "===== 2) customer-facing inline reply: lines ====="
grep -n "reply:" routes/whatsapp.js | head -50

echo; echo "===== 3) template KEYS referenced (watpl.compose) ====="
grep -noE "whatsapp\.[a-z_]+" routes/whatsapp.js | sort -u

echo; echo "===== 4) watpl.js — how templates are stored (table/columns) ====="
cat -n lib/watpl.js 2>/dev/null | head -55

echo; echo "===== 5) DB: template bodies + IPTV library status ====="
cat > .q.js <<'JS'
require('/opt/gsz/node_modules/dotenv').config({ path: '/opt/gsz/.env' });
const { Pool } = require('/opt/gsz/node_modules/pg');
const p = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
(async () => {
  for (const t of ['wa_templates', 'wa_message_templates', 'message_templates', 'templates']) {
    try { const r = await p.query('SELECT * FROM ' + t + ' ORDER BY 1 LIMIT 60'); console.log('=== templates table: ' + t + ' (' + r.rows.length + ' rows) ==='); r.rows.forEach(row => console.log(JSON.stringify(row))); break; } catch (e) {}
  }
  try {
    const r = await p.query("SELECT server_key,name,live_count,vod_count,series_count,episode_count,status,updated_at, round(extract(epoch from (now()-updated_at))/3600.0,1) AS age_h FROM iptv_library ORDER BY updated_at DESC NULLS LAST");
    console.log('=== iptv_library (' + r.rows.length + ' rows) ===');
    r.rows.forEach(x => console.log([x.server_key, 'L' + x.live_count, 'V' + x.vod_count, 'S' + x.series_count, 'E' + x.episode_count, x.status, (x.age_h == null ? '?' : x.age_h + 'h'), x.updated_at ? new Date(x.updated_at).toISOString().slice(0, 16) : 'never'].join(' | ')));
  } catch (e) { console.log('iptv_library err: ' + e.message); }
  await p.end();
})();
JS
node .q.js 2>&1 | head -120
rm -f .q.js
echo DONE
