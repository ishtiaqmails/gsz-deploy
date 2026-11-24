'use strict';
// lib/planSync.js — keep each mapped server's plan LIST (durations) in sync with its bot product.
// The bot product defines which durations exist; the OWNER keeps prices AND the labels they already use.
// Durations are matched by MONTH-COUNT (so "1 Year" == "12 Months" == "12m"), never by raw text, so an
// existing priced plan is recognised and kept — no duplicate rows. A bot duration with no existing match
// is added unpriced (price 0 -> hidden from the store until the owner sets a price). A priced plan the
// bot no longer lists is preserved (never silently drop a plan that still sells).
const gszApi = require('./gszApi');
let _defPool = null;
try { _defPool = require('../db').pool; } catch (e) { _defPool = null; }

function norm(s) { return String(s || '').toLowerCase().replace(/\s+/g, '').trim(); }
function durKey(s) {
  s = String(s || '').toLowerCase(); let m;
  if ((m = s.match(/(\d+)\s*(years?|yrs?|y)\b/))) return (+m[1]) * 12;
  if ((m = s.match(/(\d+)\s*(months?|mons?|mo|m)\b/))) return +m[1];
  if ((m = s.match(/^(\d+)m$/))) return +m[1];
  return null;
}

async function syncServer(pool, sv, plist) {
  const p = plist.find(function (y) { return String(y.sku) === String(sv.bot_sku); });
  if (!p || !Array.isArray(p.plans)) return { skipped: true };
  const botPlans = p.plans.filter(function (d) { return d && String(d.plan_key) !== 'trial' && d.label; });
  if (!botPlans.length) return { skipped: true };
  const existing = (await pool.query('SELECT id,label,price,price_usd,save FROM server_plans WHERE server_id=$1 ORDER BY sort, id', [sv.id])).rows;
  const items = existing.map(function (r) { return { r: r, used: false }; });
  function take(label) {
    const dk = durKey(label), nl = norm(label);
    let pool1 = items.filter(function (x) { return !x.used && norm(x.r.label) === nl; });
    if (!pool1.length && dk != null) pool1 = items.filter(function (x) { return !x.used && durKey(x.r.label) === dk; });
    if (!pool1.length) return null;
    pool1.sort(function (a, b) { return (Number(b.r.price) > 0 ? 1 : 0) - (Number(a.r.price) > 0 ? 1 : 0); });
    pool1[0].used = true; return pool1[0].r;
  }
  const desired = [];
  botPlans.forEach(function (d) {
    const ex = take(d.label);
    // Bot label is canonical everywhere; carry the owner's price over from the matched row.
    if (ex) desired.push({ label: d.label, price: Number(ex.price) || 0, price_usd: Number(ex.price_usd) || 0, save: Number(ex.save) || 0 });
    else desired.push({ label: d.label, price: 0, price_usd: 0, save: 0 });
  });
  items.forEach(function (x) { if (!x.used && Number(x.r.price) > 0) desired.push({ label: x.r.label, price: Number(x.r.price) || 0, price_usd: Number(x.r.price_usd) || 0, save: Number(x.r.save) || 0 }); });

  const same = existing.length === desired.length && existing.every(function (r, i) {
    const d = desired[i]; return d && r.label === d.label && Number(r.price) === Number(d.price) && Number(r.price_usd) === Number(d.price_usd) && Number(r.save) === Number(d.save);
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
  const added = desired.filter(function (d) { return Number(d.price) <= 0; }).length;
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
    let changed = 0, addedUnpriced = 0;
    for (const sv of servers) {
      try { const r = await syncServer(pool, sv, plist); if (r && r.changed) { changed++; addedUnpriced += (r.added || 0); } } catch (e) {}
    }
    return { ok: true, servers: servers.length, changed: changed, unpriced: addedUnpriced };
  } finally { _running = false; }
}

module.exports = { syncAll, syncServer };
