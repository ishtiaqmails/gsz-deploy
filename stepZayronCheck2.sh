#!/usr/bin/env bash
# stepZayronCheck2 — READ-ONLY. Disambiguate two readiness flags:
#  (1) is Meezan really missing from the shared ledger, or was it a transient blip? (poll x3)
#  (2) is provisioning actually working in production? (recent order outcomes + re-try dry-run)
set -e
cd /opt/zayron
node <<'NODE'
const { pool } = require('./db');
(async () => {
  const log = (...a) => console.log(...a);
  const gszApi = require('./lib/gszApi');

  // (1) poll pay-accounts 3x (cache TTL is short) to see if meezan comes back
  log('[accounts] polling gsz-api pay-accounts x3:');
  for (let i = 0; i < 3; i++) {
    try { const pa = await gszApi.getPayAccounts(); log('  try' + (i + 1) + ':', (pa.accounts || []).map(a => a.key).sort().join(', ') || '(none)'); }
    catch (e) { log('  try' + (i + 1) + ' ERR', e.message); }
    await new Promise(r => setTimeout(r, 2500));
  }

  // (2) are recent orders actually completing? last 8 orders with outcome
  try {
    const r = (await pool.query(
      "SELECT ref, status, (line_user IS NOT NULL) AS has_creds, created_at, updated_at " +
      "FROM orders ORDER BY id DESC LIMIT 8")).rows;
    log('\n[orders] last 8:');
    r.forEach(o => log('  ' + o.ref, '| ' + o.status, '| creds=' + o.has_creds, '| created ' + new Date(o.created_at).toISOString().slice(0, 16)));
    const d = (await pool.query("SELECT COUNT(*)::int n FROM orders WHERE status='delivered' AND updated_at > now() - interval '7 days'")).rows[0].n;
    log('[orders] delivered in last 7 days:', d);
  } catch (e) { log('[orders] query err', e.message); }

  // (3) re-try the dry-run dispatch on the most recent order that actually has a server+creds
  try {
    const worker = require('./lib/orderWorker')(pool, console);
    const o = (await pool.query("SELECT * FROM orders WHERE status='delivered' AND server_id IS NOT NULL AND line_user IS NOT NULL ORDER BY id DESC LIMIT 1")).rows[0];
    if (!o) { log('\n[dispatch] no delivered order with a server to dry-run'); }
    else {
      const t0 = Date.now();
      const rr = await worker.dispatchOrder(o, true);
      log('\n[dispatch] dry-run of', o.ref, '(' + (Date.now() - t0) + 'ms) =>', JSON.stringify(rr).slice(0, 300));
    }
  } catch (e) { log('\n[dispatch] dry-run error:', e.message); }

  log('\nCHECK DONE — nothing changed.');
  process.exit(0);
})();
NODE
