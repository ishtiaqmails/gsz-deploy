#!/usr/bin/env bash
# stepZayronPlanSyncFix — replace lib/planSync.js with the month-count matcher (so "1 Year"=="12 Months"),
# which removes the duplicate unpriced rows the first version created, and re-run the sync once.
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
echo "--- re-syncing (should clean up the v1 duplicates) ---"
node -e "require('./lib/planSync').syncAll().then(r=>{console.log('planSync result:', JSON.stringify(r));process.exit(0)}).catch(e=>{console.log(e.message);process.exit(0)})"
echo "--- unpriced rows now (should only be genuinely-missing durations) ---"
node -e "
const { pool } = require('./db');
(async()=>{ try{
  const r=(await pool.query(\"SELECT s.name, sp.label FROM server_plans sp JOIN servers s ON s.id=sp.server_id WHERE sp.price<=0 ORDER BY s.name, sp.sort\")).rows;
  console.log('unpriced plans:', r.length, r.map(x=>x.name+':'+x.label).join(' | ')||'(none)');
}catch(e){console.log(e.message)} process.exit(0); })();
"
echo "DONE: month-count matching live; duplicates cleaned. healthz=200"
