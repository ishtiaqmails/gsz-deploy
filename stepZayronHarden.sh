#!/usr/bin/env bash
# stepZayronHarden — make the order pipeline bulletproof for 24/7:
#  1. overlap guards on runDispatch/runVerify/runCollect so a slow tick can never run twice at
#     once (prevents the same verified order being dispatched twice = wasted line/credit).
#  2. sweepStuckVerifying(): any payment not auto-matched within 48h -> 'review' (never silent).
# Error paths already fail safe (gsz-api down -> stays verifying & retries; bot fail -> review).
# Safe: backup, single-match anchors + auto-revert, node --check, restart zayron-orders only.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zhd; rm -rf "$W"; mkdir -p "$W/p"
cp lib/orderWorker.js "$W/orderWorker.js.bak"
revert(){ cp "$W/orderWorker.js.bak" lib/orderWorker.js; }

# ---- A) sweepStuckVerifying() inserted before start() ----
cat > "$W/p/o1" <<'OLD'
  function start(everyMs) {
OLD
cat > "$W/p/n1" <<'NEW'
  // Any payment that never auto-matched within 48h -> 'review', so nothing sits silently stuck.
  async function sweepStuckVerifying() {
    try {
      const r = await pool.query(
        "UPDATE orders SET status='review', note=COALESCE(note,'') || ' | payment not auto-matched in 48h', updated_at=now() " +
        "WHERE status='verifying' AND created_at < now() - interval '48 hours' RETURNING ref");
      if (r.rowCount) log.log('[orderWorker] stuck verifying -> review:', r.rows.map(function (x) { return x.ref; }).join(', '));
    } catch (e) { if (log.error) log.error('[orderWorker] sweepStuckVerifying:', e.message); }
  }

  function start(everyMs) {
NEW

# ---- B) overlap guards on the three hot loops ----
cat > "$W/p/o2" <<'OLD'
    setInterval(function () { runDispatch(false).catch(function () {}); }, ms);
    setInterval(function () { runVerify().catch(function () {}); }, ms);
    setInterval(function () { runCollect().catch(function () {}); }, ms);
OLD
cat > "$W/p/n2" <<'NEW'
    // overlap guards: a loop never runs twice at once (prevents double-dispatch)
    var _busy = { d: false, v: false, c: false };
    setInterval(function () { if (_busy.d) return; _busy.d = true; Promise.resolve(runDispatch(false)).catch(function () {}).then(function () { _busy.d = false; }); }, ms);
    setInterval(function () { if (_busy.v) return; _busy.v = true; Promise.resolve(runVerify()).catch(function () {}).then(function () { _busy.v = false; }); }, ms);
    setInterval(function () { if (_busy.c) return; _busy.c = true; Promise.resolve(runCollect()).catch(function () {}).then(function () { _busy.c = false; }); }, ms);
NEW

# ---- C) schedule the sweep (hourly, next to expireUnpaid) ----
cat > "$W/p/o3" <<'OLD'
    setInterval(function () { expireUnpaid().catch(function () {}); }, 60 * 60 * 1000);
OLD
cat > "$W/p/n3" <<'NEW'
    setInterval(function () { expireUnpaid().catch(function () {}); }, 60 * 60 * 1000);
    setInterval(function () { sweepStuckVerifying().catch(function () {}); }, 60 * 60 * 1000);
NEW

# ---- D) export the sweep ----
cat > "$W/p/o4" <<'OLD'
  return { runDispatch, runCollect, runVerify, dispatchOrder, start, enabled, purgeOldProofs, expireUnpaid };
OLD
cat > "$W/p/n4" <<'NEW'
  return { runDispatch, runCollect, runVerify, dispatchOrder, start, enabled, purgeOldProofs, expireUnpaid, sweepStuckVerifying };
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zhd/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('lib/orderWorker.js','o1','n1');
rep('lib/orderWorker.js','o2','n2');
rep('lib/orderWorker.js','o3','n3');
rep('lib/orderWorker.js','o4','n4');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check lib/orderWorker.js || { echo "syntax error - reverting"; revert; exit 1; }

pm2 restart zayron-orders >/dev/null 2>&1 || pm2 restart zayron-orders
sleep 1
echo "--- zayron-orders ---"; pm2 describe zayron-orders | grep -iE "status|restarts|uptime"
echo "DONE: overlap guards + stuck-verifying sweep live. Delivery/verify logic unchanged."
