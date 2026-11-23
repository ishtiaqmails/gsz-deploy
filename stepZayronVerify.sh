#!/usr/bin/env bash
# stepZayronVerify — swap zayron's payment VERIFY onto the shared gsz-api ledger (one payment system).
#  - gszApi.js: env fallback (works in any process) + methodKey() name->account mapper
#  - orderWorker.js: runVerify() polls 'verifying' orders via gsz-api verify-claim (genuine->verified, fraud->review)
#  - checkout.js /paid: immediate verify-claim instead of local payMatch
# Delivery (orderDispatch) and the checkout UI are UNCHANGED. MCB (not on the ledger) stays manual.
# Safe: backups, single-match anchors, node --check, auto-rollback, restart zayron + zayron-orders.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zvf; rm -rf "$W"; mkdir -p "$W/p"
cp lib/gszApi.js "$W/gszApi.js.bak"
cp lib/orderWorker.js "$W/orderWorker.js.bak"
cp routes/checkout.js "$W/checkout.js.bak"
revert(){ cp "$W/gszApi.js.bak" lib/gszApi.js; cp "$W/orderWorker.js.bak" lib/orderWorker.js; cp "$W/checkout.js.bak" routes/checkout.js; }

# ---- gszApi.js: env fallback ----
cat > "$W/p/o1" <<'OLD'
const { URL } = require('url');
OLD
cat > "$W/p/n1" <<'NEW'
const { URL } = require('url');

// env fallback: ensure the gsz-api creds are present even if this process didn't load .env
if (!process.env.GSZ_BOT_API_URL) {
  try { require('fs').readFileSync(require('path').join(__dirname, '..', '.env'), 'utf8').split('\n').forEach(function (l) { var mm = l.match(/^(GSZ_BOT_API_(?:URL|KEY))=(.*)$/); if (mm && !process.env[mm[1]]) process.env[mm[1]] = mm[2].trim(); }); } catch (e) {}
}
NEW

# ---- gszApi.js: methodKey + export ----
cat > "$W/p/o2" <<'OLD'
module.exports = { configured, getPayAccounts, verifyClaim, orderStatus, submitOrder };
OLD
cat > "$W/p/n2" <<'NEW'
// map a zayron payment-method name/type to the gsz-api account key it settles into.
function methodKey(s) { s = String(s || '').toLowerCase(); if (/binance|usdt|crypto/.test(s)) return 'binance'; if (/naya/.test(s)) return 'nayapay'; if (/meezan/.test(s)) return 'meezan'; return null; }

module.exports = { configured, getPayAccounts, verifyClaim, orderStatus, submitOrder, methodKey };
NEW

# ---- orderWorker.js: require gszApi ----
cat > "$W/p/o3" <<'OLD'
const dispatch = require('./orderDispatch');
OLD
cat > "$W/p/n3" <<'NEW'
const dispatch = require('./orderDispatch');
const gszApi = require('./gszApi');
NEW

# ---- orderWorker.js: insert runVerify() before start() ----
cat > "$W/p/o4" <<'OLD'
  function start(everyMs) {
OLD
cat > "$W/p/n4" <<'NEW'
  // VERIFY via the shared gsz-api ledger: poll 'verifying' orders and claim atomically.
  async function runVerify() {
    if (!gszApi.configured()) return 0;
    let rows;
    try {
      rows = (await pool.query(
        "SELECT o.id, o.ref, o.pay_amount, o.proof_hash, o.created_at, pm.name AS pm_name " +
        "FROM orders o LEFT JOIN payment_methods pm ON pm.id = o.pay_method_id " +
        "WHERE o.status='verifying' AND o.created_at > now() - interval '48 hours' ORDER BY o.id ASC LIMIT 10")).rows;
    } catch (e) { log.error('[orderWorker] runVerify query:', e.message); return 0; }
    let n = 0;
    for (const o of rows) {
      const key = gszApi.methodKey(o.pm_name);
      if (!key) continue; // method not on the shared ledger (e.g. MCB) -> leave for manual review
      try {
        const vr = await gszApi.verifyClaim({
          amount: Number(o.pay_amount) || 0,
          since: new Date(o.created_at).getTime(),
          ref: o.ref, method: key,
          screenshotHash: o.proof_hash || undefined
        });
        if (vr && vr.result === 'genuine') {
          await pool.query("UPDATE orders SET status='verified', updated_at=now() WHERE id=$1", [o.id]);
          log.log('[orderWorker] verified', o.ref, vr.idempotent ? '(idempotent)' : ''); n++;
        } else if (vr && vr.result === 'fraud_consumed') {
          await pool.query("UPDATE orders SET status='review', note=COALESCE(note,'') || ' | payment: duplicate/fraud', updated_at=now() WHERE id=$1", [o.id]);
        }
      } catch (e) { /* pending / transient -> retry next tick */ }
    }
    return n;
  }

  function start(everyMs) {
NEW

# ---- orderWorker.js: schedule runVerify ----
cat > "$W/p/o5" <<'OLD'
    setInterval(function () { runDispatch(false).catch(function () {}); }, ms);
OLD
cat > "$W/p/n5" <<'NEW'
    setInterval(function () { runDispatch(false).catch(function () {}); }, ms);
    setInterval(function () { runVerify().catch(function () {}); }, ms);
NEW

# ---- orderWorker.js: export runVerify ----
cat > "$W/p/o6" <<'OLD'
  return { runDispatch, runCollect, dispatchOrder, start, enabled, purgeOldProofs, expireUnpaid };
OLD
cat > "$W/p/n6" <<'NEW'
  return { runDispatch, runCollect, runVerify, dispatchOrder, start, enabled, purgeOldProofs, expireUnpaid };
NEW

# ---- checkout.js /paid: verify via gsz-api ----
cat > "$W/p/o7" <<'OLD'
      try { await payMatch.reconcileOrder(o.id); } catch (e) {}
OLD
cat > "$W/p/n7" <<'NEW'
      // VERIFY via the shared gsz-api ledger (one payment system). Pending -> orderWorker polls it.
      try {
        const _gszApi = require('../lib/gszApi');
        const _key = _gszApi.methodKey(m && m.name);
        if (_key) {
          const _vr = await _gszApi.verifyClaim({ amount: Number(payAmount) || 0, since: new Date(o.created_at || Date.now()).getTime(), ref: o.ref, method: _key, screenshotHash: proofHash || undefined });
          if (_vr && _vr.result === 'genuine') await pool.query("UPDATE orders SET status='verified', updated_at=now() WHERE id=$1", [o.id]);
          else if (_vr && _vr.result === 'fraud_consumed') await pool.query("UPDATE orders SET status='review', note=COALESCE(note,'') || ' | payment: duplicate/fraud', updated_at=now() WHERE id=$1", [o.id]);
        }
      } catch (e) {}
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zvf/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+'] in '+file+': '+o.slice(0,60)); process.exit(5);} fs.writeFileSync(file, s.replace(o,function(){return n;})); }
rep('lib/gszApi.js','o1','n1');
rep('lib/gszApi.js','o2','n2');
rep('lib/orderWorker.js','o3','n3');
rep('lib/orderWorker.js','o4','n4');
rep('lib/orderWorker.js','o5','n5');
rep('lib/orderWorker.js','o6','n6');
rep('routes/checkout.js','o7','n7');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
for f in lib/gszApi.js lib/orderWorker.js routes/checkout.js; do node --check "$f" || { echo "syntax error in $f - reverting"; revert; exit 1; }; done

pm2 restart zayron zayron-orders >/dev/null 2>&1 || pm2 restart zayron zayron-orders
echo "DONE: verify now runs through the shared gsz-api ledger (orderWorker + checkout). Delivery + UI unchanged."
