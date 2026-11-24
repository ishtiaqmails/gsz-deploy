#!/usr/bin/env bash
# stepZayronPlanSync — plan LIST (durations) auto-maps from the mapped bot product; owner keeps prices.
#  - new lib/planSync.js (bot defines durations/order; prices preserved by label; unpriced = hidden)
#  - server.js runs it 8s after boot + every 15 min
#  - lib/data.js public store shows only priced plans; routes/checkout.js refuses unpriced plans
# Safe: backup, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp server.js "$B/"; cp lib/data.js "$B/"; cp routes/checkout.js "$B/"
[ -f lib/planSync.js ] && cp lib/planSync.js "$B/" || true
revert(){ cp "$B/server.js" server.js; cp "$B/data.js" lib/data.js; cp "$B/checkout.js" routes/checkout.js; [ -f "$B/planSync.js" ] && cp "$B/planSync.js" lib/planSync.js || rm -f lib/planSync.js; pm2 restart zayron >/dev/null 2>&1 || true; }

# ---- the engine (committed as libPlanSync.js in the deploy repo, copied into place) ----
cp /opt/gsz-deploy/libPlanSync.js lib/planSync.js

T="$(mktemp -d)"
# server.js: start the sync after the admin router require
cat > "$T/s_o" <<'O'
const adminRouter = require('./routes/admin');
O
cat > "$T/s_n" <<'O'
const adminRouter = require('./routes/admin');
const planSync = require('./lib/planSync');
setTimeout(function(){ try{ planSync.syncAll().then(function(r){ console.log('[planSync] boot', JSON.stringify(r)); }).catch(function(){}); }catch(e){} }, 8000);
setInterval(function(){ try{ planSync.syncAll().catch(function(){}); }catch(e){} }, 15*60*1000);
O

# data.js: public store shows only priced plans
cat > "$T/d_o" <<'O'
  const plans = (await pool.query(`SELECT * FROM server_plans ORDER BY sort, id`)).rows;
O
cat > "$T/d_n" <<'O'
  const plans = (await pool.query(`SELECT * FROM server_plans WHERE price > 0 ORDER BY sort, id`)).rows;
O

# checkout.js: refuse an unpriced plan
cat > "$T/c_o" <<'O'
      const plans = (await pool.query('SELECT * FROM server_plans WHERE server_id=$1 ORDER BY sort, id', [sv.id])).rows;
O
cat > "$T/c_n" <<'O'
      const plans = (await pool.query('SELECT * FROM server_plans WHERE server_id=$1 AND price > 0 ORDER BY sort, id', [sv.id])).rows;
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('server.js', [['s_o','s_n']]);
patch('lib/data.js', [['d_o','d_n']]);
patch('routes/checkout.js', [['c_o','c_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check lib/planSync.js && node --check server.js && node --check lib/data.js && node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "--- running one sync now to report what the bot adds ---"
node -e "require('./lib/planSync').syncAll().then(r=>{console.log('planSync result:', JSON.stringify(r));process.exit(0)}).catch(e=>{console.log(e.message);process.exit(0)})"
echo "DONE: plan durations auto-map from bot (prices kept); unpriced hidden. healthz=200"
