#!/usr/bin/env bash
# stepZayronAdminSpeed — kill the dead-reseller-DB hangs that make admin crawl AND were hiding
# Buy/Trial. Rewrites 3 helpers to resolve through the gsz-api bridge (by the server's mapped
# bot_sku) + the local DB — no 10.104.0.2, no 8s timeouts, no hardcoded passwords:
#   - trialToggle.isTrialDisabled  -> bridge product.trial.enabled
#   - paidToggle.panelSellable     -> bridge product has a non-trial plan (masterPaidOn stays local)
#   - panels.getPanels             -> distinct reseller_pid already on servers (instant, local)
# Caller signatures unchanged (they pass reseller_pid, resolved to bot_sku internally). Safe: backups + check.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp lib/trialToggle.js "$B/" ; cp lib/paidToggle.js "$B/" ; cp lib/panels.js "$B/"

cat > lib/trialToggle.js <<'TT'
// lib/trialToggle.js — is the automated trial AVAILABLE for a server? Resolves via the gsz-api
// bridge using the server's mapped bot_sku. No reseller DB. Fail-safe: unknown -> disabled (manual).
const { pool } = require('../db');
const gszApi = require('./gszApi');
const _cache = new Map(); // key -> { disabled, at }
const TTL = 10 * 1000;
async function _skuFor(key) {
  try { const r = await pool.query('SELECT bot_sku FROM servers WHERE reseller_pid=$1 OR bot_sku=$1 LIMIT 1', [key]); return (r.rows[0] && r.rows[0].bot_sku) ? String(r.rows[0].bot_sku) : null; }
  catch (e) { return null; }
}
async function isTrialDisabled(resellerPidOrSku) {
  const key = String(resellerPidOrSku || '').trim();
  if (!key) return true;
  const hit = _cache.get(key); if (hit && Date.now() - hit.at < TTL) return hit.disabled;
  try {
    const sku = await _skuFor(key);
    if (!sku) { _cache.set(key, { disabled: true, at: Date.now() }); return true; }
    const prod = await gszApi.getProducts();
    const p = ((prod && prod.products) || []).find(function (y) { return String(y.sku) === sku; });
    const disabled = !(p && p.trial && p.trial.enabled);
    _cache.set(key, { disabled: disabled, at: Date.now() });
    return disabled;
  } catch (e) { return true; }
}
module.exports = { isTrialDisabled };
TT
node --check lib/trialToggle.js || { echo "trialToggle syntax err"; cp "$B/trialToggle.js" lib/; exit 1; }

cat > lib/paidToggle.js <<'PT'
// lib/paidToggle.js — is LIVE paid delivery available for a server? masterPaidOn reads the local
// website switches; panelSellable resolves via the gsz-api bridge (the server's mapped bot_sku).
// No reseller DB. Fail-safe: unknown -> false (manual WhatsApp).
const { pool } = require('../db');
const gszApi = require('./gszApi');
let _masterCache = { on: null, at: 0 };
const MASTER_TTL = 3 * 1000;
async function masterPaidOn() {
  if (_masterCache.on !== null && Date.now() - _masterCache.at < MASTER_TTL) return _masterCache.on;
  try {
    const r = await pool.query("SELECT key, value FROM settings WHERE key IN ('web_paid_on','store_manual')");
    const m = {}; r.rows.forEach(function (x) { m[x.key] = String(x.value); });
    if (m.store_manual === '1') { _masterCache = { on: false, at: Date.now() }; return false; }
    const on = ('web_paid_on' in m) ? m.web_paid_on !== '0' : true;
    _masterCache = { on: on, at: Date.now() }; return on;
  } catch (e) { return false; }
}
const _cache = new Map(); const TTL = 10 * 1000;
async function _skuFor(key) {
  try { const r = await pool.query('SELECT bot_sku FROM servers WHERE reseller_pid=$1 OR bot_sku=$1 LIMIT 1', [key]); return (r.rows[0] && r.rows[0].bot_sku) ? String(r.rows[0].bot_sku) : null; }
  catch (e) { return null; }
}
async function panelSellable(resellerPidOrSku) {
  const key = String(resellerPidOrSku || '').trim(); if (!key) return false;
  const hit = _cache.get(key); if (hit && Date.now() - hit.at < TTL) return hit.ok;
  try {
    const sku = await _skuFor(key);
    if (!sku) { _cache.set(key, { ok: false, at: Date.now() }); return false; }
    const prod = await gszApi.getProducts();
    const p = ((prod && prod.products) || []).find(function (y) { return String(y.sku) === sku; });
    const plans = (p && Array.isArray(p.plans)) ? p.plans : [];
    const ok = plans.some(function (d) { return d && String(d.plan_key) !== 'trial'; });
    _cache.set(key, { ok: ok, at: Date.now() }); return ok;
  } catch (e) { return false; }
}
async function isPaidLive(resellerPidOrSku) {
  try { if (!(await masterPaidOn())) return false; return await panelSellable(resellerPidOrSku); }
  catch (e) { return false; }
}
module.exports = { isPaidLive, masterPaidOn, panelSellable };
PT
node --check lib/paidToggle.js || { echo "paidToggle syntax err"; cp "$B/paidToggle.js" lib/; exit 1; }

cat > lib/panels.js <<'PN'
// lib/panels.js — panel list for the admin dropdown. The reseller bot DB is no longer reachable
// cross-VPS, so this derives the list from the panels already set on servers (instant, local).
const { pool } = require('../db');
let _cache = { at: 0, list: [] };
const TTL = 30 * 1000;
async function getPanels() {
  if (Date.now() - _cache.at < TTL && _cache.list.length) return _cache.list;
  try {
    const r = await pool.query("SELECT DISTINCT reseller_pid AS id FROM servers WHERE reseller_pid IS NOT NULL AND reseller_pid<>'' ORDER BY reseller_pid");
    const list = r.rows.map(function (x) { return { id: x.id, name: x.id, type: '' }; });
    if (list.length) _cache = { at: Date.now(), list: list };
    return list;
  } catch (e) { return _cache.list; }
}
module.exports = { getPanels };
PN
node --check lib/panels.js || { echo "panels syntax err"; cp "$B/panels.js" lib/; exit 1; }

pm2 restart zayron zayron-orders >/dev/null 2>&1 || pm2 restart zayron zayron-orders
sleep 1
echo "--- quick timing check (should be well under 1s each) ---"
node -e "const t=require('./lib/trialToggle'),p=require('./lib/paidToggle');(async()=>{let s=Date.now();await t.isTrialDisabled('strong8k');console.log('isTrialDisabled strong8k:',(Date.now()-s)+'ms');s=Date.now();console.log('panelSellable strong8k:',await p.panelSellable('strong8k'),(Date.now()-s)+'ms');s=Date.now();await require('./lib/panels').getPanels();console.log('getPanels:',(Date.now()-s)+'ms');process.exit(0)})()"
echo "DONE: admin + product pages no longer wait on the dead reseller DB. Backups in $B"
