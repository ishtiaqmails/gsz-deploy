#!/usr/bin/env bash
# stepZayronDryrun — READ-ONLY readiness check for the automated store. Makes NO changes and
# NO restarts. Confirms: toggle state, payment-method -> ledger mapping (exposes MCB), gsz-api
# connectivity + a harmless non-matching verify probe, and the provisioning mapping via a
# dry-run dispatch of the most recent real order (dryRun => builds payload, creates nothing).
set -e
cd /opt/zayron
echo "### processes ###"
pm2 ls | grep -iE "zayron" || true

node <<'NODE'
const { pool } = require('./db');
(async () => {
  const log = (...a) => console.log(...a);
  try {
    // --- toggle state ---
    const storeMode = require('./lib/storeMode');
    const paidToggle = require('./lib/paidToggle');
    const manual = await storeMode.storeManual();
    log('\n[toggle] store_manual =', manual, manual ? '(MANUAL — store offline)' : '(LIVE)');
    try { log('[toggle] paid buys live (masterPaidOn) =', await paidToggle.masterPaidOn()); } catch (e) { log('[toggle] masterPaidOn err', e.message); }

    // --- payment methods -> shared-ledger mapping ---
    const gszApi = require('./lib/gszApi');
    const pms = (await pool.query("SELECT id,name,active FROM payment_methods ORDER BY id")).rows;
    log('\n[methods] zayron payment methods and how each maps to the shared ledger:');
    pms.forEach(m => {
      const key = gszApi.methodKey(m.name);
      log('  #' + m.id, m.name, '| active=' + m.active, '| ledger=' + (key || 'NONE  <-- cannot auto-verify (drop or keep manual)'));
    });

    // --- gsz-api connectivity + safe non-matching verify probe ---
    try {
      const pa = await gszApi.getPayAccounts();
      log('\n[gsz-api] connected, accounts:', (pa.accounts || []).map(a => a.key).join(', '));
    } catch (e) { log('\n[gsz-api] getPayAccounts FAILED:', e.message); }
    try {
      const probe = await gszApi.verifyClaim({ amount: 1, since: Date.now() - 60000, ref: 'DRYRUN-' + Date.now(), method: 'meezan' });
      log('[gsz-api] verify probe (expect pending/no-match):', JSON.stringify(probe));
    } catch (e) { log('[gsz-api] verify probe error:', e.message); }

    // --- provisioning mapping: dry-run dispatch a recent real order (creates nothing) ---
    try {
      const worker = require('./lib/orderWorker')(pool, console);
      const o = (await pool.query("SELECT * FROM orders WHERE server_id IS NOT NULL ORDER BY id DESC LIMIT 1")).rows[0];
      if (!o) { log('\n[dispatch] no order with a server to dry-run'); }
      else {
        const r = await worker.dispatchOrder(o, true); // dryRun = true
        log('\n[dispatch] dry-run of order', o.ref, '=>', JSON.stringify(r).slice(0, 400));
        log('           (ok:true + payload = provisioning mapping resolves; error = config to fix before live)');
      }
    } catch (e) { log('\n[dispatch] dry-run error:', e.message); }

    log('\nREADINESS CHECK DONE — nothing was changed.');
  } catch (e) { log('FATAL', e.message); }
  process.exit(0);
})();
NODE
