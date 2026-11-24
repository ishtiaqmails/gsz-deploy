#!/usr/bin/env bash
# READ-ONLY. Traces the most recent trial end-to-end: zayron row -> bridge trial-status -> product trial flag.
Z=/opt/zayron; cd "$Z"
node -e '
const { pool } = require("./db");
const gszApi = require("./lib/gszApi");
(async () => {
  const t = (await pool.query("SELECT id,server_id,phone,status,bot_job_id,claim_token,created_at FROM trials ORDER BY id DESC LIMIT 1")).rows[0];
  console.log("ZAYRON TRIAL ROW:", JSON.stringify(t));
  if (!t) { process.exit(0); }
  const sv = (await pool.query("SELECT id,slug,bot_sku,reseller_pid FROM servers WHERE id=$1",[t.server_id])).rows[0];
  console.log("SERVER:", JSON.stringify(sv));
  console.log("gszApi.configured:", gszApi.configured ? gszApi.configured() : "(n/a)");
  try { const st = await gszApi.trialStatus(t.claim_token); console.log("BRIDGE trial-status:", JSON.stringify(st)); } catch (e) { console.log("trialStatus ERR:", e.message); }
  try { const pr = await gszApi.getProducts(); const p = (pr||[]).find(x => String(x.sku)===String(sv && sv.bot_sku)); console.log("PRODUCT trial flag:", p ? JSON.stringify({sku:p.sku, trial:p.trial, types:p.types, plans:(p.plans||[]).length}) : "(bot_sku not in /api/products)"); } catch (e) { console.log("getProducts ERR:", e.message); }
  process.exit(0);
})().catch(e => { console.error("ERR:", e.message); process.exit(1); });
'
