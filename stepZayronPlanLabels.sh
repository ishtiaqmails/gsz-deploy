#!/usr/bin/env bash
# stepZayronPlanLabels — use the BOT's duration label on every server (price carried over by month-count),
# so all servers read 1 Month / 3 Months / 6 Months / 12 Months consistently. Re-runs the sync once.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp lib/planSync.js "$B/planSync.js.bak"
revert(){ cp "$B/planSync.js.bak" lib/planSync.js; pm2 restart zayron >/dev/null 2>&1 || true; }

cp /opt/gsz-deploy/libPlanSync.js lib/planSync.js
node --check lib/planSync.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "--- applying bot labels across all servers ---"
node -e "require('./lib/planSync').syncAll().then(r=>{console.log('planSync result:', JSON.stringify(r));process.exit(0)}).catch(e=>{console.log(e.message);process.exit(0)})"
echo "--- labels now (per server) ---"
node -e "
const { pool } = require('./db');
(async()=>{ try{
  const r=(await pool.query(\"SELECT s.name, string_agg(sp.label, ', ' ORDER BY sp.sort) AS labels FROM server_plans sp JOIN servers s ON s.id=sp.server_id WHERE sp.price>0 GROUP BY s.name ORDER BY s.name\")).rows;
  r.forEach(x=>console.log(' -', x.name+':', x.labels));
}catch(e){console.log(e.message)} process.exit(0); })();
"
echo "DONE: bot labels applied everywhere. healthz=200"
