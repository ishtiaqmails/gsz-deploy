'use strict';
// lib/planSync.js — keep each mapped server's plan LIST (durations) in sync with its bot product.
// The bot product defines which durations exist (1M/3M/6M/12M) and their order; the OWNER keeps prices.
// New bot durations are added unpriced (price 0 -> hidden from the store until the owner sets a price).
// A PRICED duration the bot no longer lists is preserved (never silently drop a plan that still sells).
// Prices are matched/carried over by normalized label, so formatting differences never lose a price.
const gszApi = require('./gszApi');
let _defPool = null;
try { _defPool = require('../db').pool; } catch (e) { _defPool = null; }

function norm(s) { return String(s || '').toLowerCase().replace(/\s+/g, '').trim(); }

async function syncServer(pool, sv, plist) {
  const p = plist.find(function (y) { return String(y.sku) === String(sv.bot_sku); });
  if (!p || !Array.isArray(p.plans)) return { skipped: true };
  const botPlans = p.plans.filter(function (d) { return d && String(d.plan_key) !== 'trial' && d.label; });
  if (!botPlans.length) return { skipped: true };
  const existing = (await pool.query('SELECT id,label,price,price_usd,save FROM server_plans WHERE server_id=$1 ORDER BY sort, id', [sv.id])).rows;
  const byNorm = new Map(); existing.forEach(function (r) { byNorm.set(norm(r.label), r); });
  const botSet = new Set(botPlans.map(function (d) { return norm(d.label); }));
  const desired = [];
  botPlans.forEach(function (d) {
    const ex = byNorm.get(norm(d.label));
    desired.push({ label: d.label, price: ex ? Number(ex.price) || 0 : 0, price_usd: ex ? Number(ex.price_usd) || 0 : 0, save: ex ? Number(ex.save) || 0 : 0 });
  });
  existing.forEach(function (r) {
    if (!botSet.has(norm(r.label)) && Number(r.price) > 0) desired.push({ label: r.label, price: Number(r.price) || 0, price_usd: Number(r.price_usd) || 0, save: Number(r.save) || 0 });
  });
  const same = existing.length === desired.length && existing.every(function (r, i) {
    const d = desired[i]; return d && norm(r.label) === norm(d.label) && Number(r.price) === Number(d.price) && Number(r.price_usd) === Number(d.price_usd) && Number(r.save) === Number(d.save);
  });
  if (same) return { changed: false };
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM server_plans WHERE server_id=$1', [sv.id]);
    for (let i = 0; i < desired.length; i++) {
      const d = desired[i];
      await client.query('INSERT INTO server_plans (server_id,label,price,save,sort,price_usd) VALUES ($1,$2,$3,$4,$5,$6)', [sv.id, d.label, d.price, d.save, i, d.price_usd]);
    }
    await client.query('COMMIT');
  } catch (e) { try { await client.query('ROLLBACK'); } catch (x) {} return { error: e.message }; } finally { client.release(); }
  const added = botPlans.filter(function (d) { return !byNorm.get(norm(d.label)); }).length;
  return { changed: true, added: added };
}

let _running = false;
async function syncAll(pool) {
  pool = pool || _defPool;
  if (!pool) return { ok: false, err: 'no pool' };
  if (_running) return { ok: false, busy: true };
  _running = true;
  try {
    let prod; try { prod = await gszApi.getProducts(); } catch (e) { return { ok: false, err: e.message }; }
    const plist = (prod && prod.products) || [];
    if (!plist.length) return { ok: false, err: 'no bot products' };
    let servers = [];
    try { servers = (await pool.query('SELECT id, bot_sku FROM servers WHERE bot_sku IS NOT NULL')).rows; } catch (e) { return { ok: false, err: e.message }; }
    let changed = 0, added = 0;
    for (const sv of servers) {
      try { const r = await syncServer(pool, sv, plist); if (r && r.changed) { changed++; added += (r.added || 0); } } catch (e) {}
    }
    return { ok: true, servers: servers.length, changed: changed, added: added };
  } finally { _running = false; }
}

module.exports = { syncAll, syncServer };
