'use strict';
/* IPTV Library Engine — server-side puller (own PM2 process, isolated from the storefront).
   Every sweep it finds the stale servers and tries to pull each one's library DIRECTLY from the VPS
   (orders-first creds). Panels the server can reach fill with no phone at all; panels behind
   Cloudflare's datacenter-IP block just fail here and are left for the phone agent. Runs the heavy
   parse in its own process so the website is never blocked. Never overwrites good data with empty. */
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const zlib = require('zlib');
const m3u = require(ROOT + '/lib/iptv/m3u');
const clean = require(ROOT + '/lib/iptv/clean');
const credsource = require(ROOT + '/lib/iptv/credsource');
const fetch = require(ROOT + '/lib/iptv/fetch');

// Convert an Xtream player_api pull (fetch.fetchAll) into the shape clean.enhance expects,
// resolving category ids to names. Used as a fallback for panels whose get.php M3U 404s.
function fromXtream(x) {
  const map = (arr, cats) => (arr || []).map(r => ({ name: r.name || r.title || '', category_name: cats[String(r.category_id)] || '', stream_icon: r.stream_icon || r.cover || '' }));
  return {
    ok: true,
    live: map(x.live, x.liveCats || {}),
    vod: map(x.vod, x.vodCats || {}),
    series: (x.series || []).map(r => ({ name: r.name || r.title || '', category_name: (x.seriesCats || {})[String(r.category_id)] || '', cover: r.cover || '', episode_count: 0 }))
  };
}

const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
const REFRESH_HOURS = 12;
const SWEEP_MS = 20 * 60 * 1000; // every 20 min
const enc = encodeURIComponent;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const ts = () => new Date().toISOString().replace('T', ' ').slice(0, 19);

async function store(server, name, enh) {
  const pack = k => enh[k].items.map(i => [i.name, (i.quality || []).join('/'), i.category, i.variants, i.episodes || 0]);
  const items = zlib.gzipSync(Buffer.from(JSON.stringify({ live: pack('live'), vod: pack('vod'), series: pack('series') })));
  const cats = { live: enh.live.categories, vod: enh.vod.categories, series: enh.series.categories };
  await pool.query(
    `INSERT INTO iptv_library(server_key,name,live_count,vod_count,series_count,episode_count,raw_live,raw_vod,raw_series,categories,items,adult_hidden,status,updated_at)
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'ok',now())
     ON CONFLICT (server_key) DO UPDATE SET name=$2,live_count=$3,vod_count=$4,series_count=$5,episode_count=$6,
       raw_live=$7,raw_vod=$8,raw_series=$9,categories=$10,items=$11,adult_hidden=$12,status='ok',updated_at=now()`,
    [server, name, enh.counts.live, enh.counts.vod, enh.counts.series, enh.counts.episodes,
     enh.rawCounts.live, enh.rawCounts.vod, enh.rawCounts.series, JSON.stringify(cats), items, enh.adult]);
}

// try one set of creds: get.php M3U first, then the Xtream player_api. Returns {ok, lib, via} or {ok:false}.
async function tryCreds(host, user, pass) {
  const url = String(host).replace(/\/+$/, '') + '/get.php?username=' + enc(user) + '&password=' + enc(pass) + '&type=m3u_plus&output=ts';
  let lib = await m3u.fetchM3U(url, 30 * 60 * 1000);
  if (lib.ok && (lib.live.length + lib.vod.length + lib.series.length) > 0) return { ok: true, lib, via: 'm3u' };
  const x = await fetch.fetchAll(host, user, pass);
  if (((x.live || []).length + (x.vod || []).length + (x.series || []).length) > 0) return { ok: true, lib: fromXtream(x), via: 'player_api' };
  return { ok: false, err: (lib.error || 'empty'), api: x.errors };
}

async function pullOne(server, name, sku) {
  // orders-first (fast, full). If that line is missing/expired/empty, recover with a fresh trial line.
  let src = 'order', r = { ok: false };
  const cr = await credsource.resolve(sku, { allowTrial: false });
  if (cr.ok) { src = cr.source; r = await tryCreds(cr.host, cr.username, cr.password); }
  if (!r.ok) {
    const t = await credsource.resolve(sku, { forceTrial: true, hours: 24, trialTimeoutMs: 120000 });
    if (t.ok) { const r2 = await tryCreds(t.host, t.username, t.password); if (r2.ok) { r = r2; src = 'trial'; } }
  }
  if (!r.ok) return { server, fail: r.err || cr.error, api: r.api };
  const total = r.lib.live.length + r.lib.vod.length + r.lib.series.length;
  if (total === 0) return { server, empty: true };
  const enh = clean.enhance(r.lib);
  await store(server, name, enh);
  return { server, source: src, via: r.via, counts: enh.counts };
}

async function staleServers() {
  const rows = (await pool.query(
    `SELECT DISTINCT p.slug, p.name, pp.bot_sku AS sku, l.updated_at,
            COALESCE(l.live_count,0)+COALESCE(l.vod_count,0)+COALESCE(l.series_count,0) AS have
       FROM products p JOIN categories c ON c.id=p.category_id
       JOIN product_plans pp ON pp.product_id=p.id
       LEFT JOIN iptv_library l ON l.server_key=p.slug
      WHERE c.slug='iptv' AND p.active AND NOT p.hidden AND pp.bot_sku IS NOT NULL AND pp.bot_sku<>''
      ORDER BY p.name`)).rows;
  const cutoff = Date.now() - REFRESH_HOURS * 3600 * 1000;
  const seen = new Set(), out = [];
  for (const r of rows) {
    if (seen.has(r.sku)) continue; seen.add(r.sku);
    const stale = !r.updated_at || (+r.have === 0) || (new Date(r.updated_at).getTime() < cutoff);
    if (stale) out.push({ server: r.slug, name: r.name, sku: r.sku });
  }
  return out;
}

let running = false;
async function sweep() {
  if (running) return; running = true;
  try {
    const list = await staleServers();
    if (!list.length) { console.log(ts(), 'all servers fresh'); return; }
    console.log(ts(), 'sweep: ' + list.length + ' stale — ' + list.map(s => s.server).join(', '));
    for (const s of list) {
      // hard per-panel cap so one slow/hanging panel never stalls the whole sweep
      const guard = new Promise(r => setTimeout(() => r({ server: s.server, timeout: true }), 12 * 60 * 1000));
      try { console.log(ts(), JSON.stringify(await Promise.race([pullOne(s.server, s.name, s.sku), guard]))); }
      catch (e) { console.log(ts(), 'ERR ' + s.server + ' ' + (e.message || e)); }
      await sleep(3000);
    }
  } catch (e) { console.log(ts(), 'SWEEP ERR ' + (e.message || e)); }
  finally { running = false; }
}

console.log(ts(), 'gsz-iptv-worker started — sweeping every ' + (SWEEP_MS / 60000) + ' min');
sweep();
setInterval(sweep, SWEEP_MS);
