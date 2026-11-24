#!/usr/bin/env bash
# resetCustomers — FULL reset of customer-facing data on zayron:
#   customers, trials, orders, otp_outbox (verification queue), sessions.
# KEEPS all store config: servers, products, settings, trial_config, pay-accounts, bot_sku mappings.
set -e
Z=/opt/zayron; cd "$Z"
node -e '
const { pool } = require("./db");
(async () => {
  const q = (s,a) => pool.query(s,a);
  const tbls = ["customers","trials","orders","otp_outbox"];
  const count = async () => { const o={}; for (const t of tbls){ try{ o[t]=(await q("SELECT count(*)::int n FROM "+t)).rows[0].n; }catch(e){ o[t]="(n/a)"; } } return o; };
  console.log("BEFORE:", JSON.stringify(await count()));
  // children first, each guarded + CASCADE so a missing table never blocks the rest
  for (const t of ["trials","otp_outbox","orders","customers"]) {
    try { await q("TRUNCATE "+t+" RESTART IDENTITY CASCADE"); console.log("cleared "+t); }
    catch(e){ console.log("skip "+t+": "+e.message); }
  }
  try { await q("TRUNCATE session"); console.log("cleared session"); } catch(e){ /* no session table */ }
  console.log("AFTER: ", JSON.stringify(await count()));
  console.log("RESET DONE — store config (servers/products/settings/trial_config/pay-accounts/bot_sku) untouched.");
  process.exit(0);
})().catch(e => { console.error("RESET FAILED:", e.message); process.exit(1); });
'
