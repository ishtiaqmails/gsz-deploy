'use strict';
/* IPTV Library Engine — server side. The phone (Termux) pulls each panel's M3U over its residential
   connection and pushes it here; we clean + de-dupe + store a tiny compressed snapshot per server.
   Self-aware: the server list comes live from the catalog (every active IPTV product + its bot sku),
   so adding/removing a panel needs no code change. Key-gated internal endpoints; public summary. */
const express = require('express');
const zlib = require('zlib');
const m3u = require('../lib/iptv/m3u');
const clean = require('../lib/iptv/clean');
const credsource = require('../lib/iptv/credsource');
const pages = require('../lib/iptv/pages');

module.exports = function (pool) {
  const router = express.Router();
  const KEY = process.env.IPTV_INGEST_KEY || '';

  function auth(req, res, next) {
    const k = req.get('x-iptv-key') || req.query.key || '';
    if (!KEY || k !== KEY) return res.status(401).json({ ok: false, error: 'unauthorized' });
    next();
  }

  // Self-aware list of IPTV servers: every active IPTV product + its bot sku, each flagged `stale`
  // (no data yet, empty, or older than the refresh window) so the agent only pulls what it needs.
  // ?stale=1 returns just the stale ones — lets the agent self-complete without re-pulling everything.
  const REFRESH_HOURS = 12;
  router.get('/internal/iptv/servers', auth, async (req, res) => {
    try {
      const rows = (await pool.query(
        `SELECT DISTINCT p.slug, p.name, pp.bot_sku AS sku, l.updated_at,
                COALESCE(l.live_count,0)+COALESCE(l.vod_count,0)+COALESCE(l.series_count,0) AS have
           FROM products p
           JOIN categories c ON c.id = p.category_id
           JOIN product_plans pp ON pp.product_id = p.id
           LEFT JOIN iptv_library l ON l.server_key = p.slug
          WHERE c.slug = 'iptv' AND p.active AND NOT p.hidden
            AND pp.bot_sku IS NOT NULL AND pp.bot_sku <> ''
          ORDER BY p.name`)).rows;
      const cutoff = Date.now() - REFRESH_HOURS * 3600 * 1000;
      const seen = new Set(), servers = [];
      rows.forEach(r => {
        if (seen.has(r.sku)) return; seen.add(r.sku);
        const stale = !r.updated_at || (+r.have === 0) || (new Date(r.updated_at).getTime() < cutoff);
        servers.push({ server: r.slug, sku: r.sku, name: r.name, have: +r.have, stale });
      });
      const out = (req.query.stale === '1') ? servers.filter(s => s.stale) : servers;
      res.json({ ok: true, servers: out });
    } catch (e) { res.status(500).json({ ok: false, error: 'server_list_failed', detail: String(e.message || e) }); }
  });

  // Resolve a read-only M3U url for one sku (creds via order/trial, cached). ?fresh=1 bypasses the
  // cache and generates a new trial — the phone uses it to self-heal an exhausted/empty link.
  router.get('/internal/iptv/url/:sku', auth, async (req, res) => {
    try {
      const fresh = req.query.fresh === '1' || req.query.fresh === 'true';
      const cr = await credsource.resolve(req.params.sku, { hours: 24, trialTimeoutMs: 150000, fresh });
      if (!cr.ok) return res.json({ ok: false, error: cr.error, detail: cr.detail });
      const base = String(cr.host).replace(/\/+$/, '');
      const url = base + '/get.php?username=' + encodeURIComponent(cr.username) + '&password=' + encodeURIComponent(cr.password) + '&type=m3u_plus&output=ts';
      res.json({ ok: true, source: cr.source, m3u_url: url, dns: cr.host });
    } catch (e) { res.status(500).json({ ok: false, error: 'resolve_failed', detail: String(e.message || e) }); }
  });

  // Receive a pushed M3U (raw body, optionally gzipped) → clean → store. octet-stream content-type
  // so no global json/urlencoded parser touches the binary body.
  router.post('/internal/iptv/ingest/:server', auth, express.raw({ type: () => true, limit: '400mb' }), async (req, res) => {
    try {
      const buf = req.body;
      if (!Buffer.isBuffer(buf) || !buf.length) return res.status(400).json({ ok: false, error: 'empty_body' });
      // stream the (gzipped) body through gunzip+readline — huge panels never sit in memory whole
      const parsed = await m3u.parseM3UData(buf);
      if (!parsed || !parsed.ok) return res.status(400).json({ ok: false, error: 'parse_failed' });
      // guard: never overwrite a good snapshot with an empty/failed fetch
      if ((parsed.live.length + parsed.vod.length + parsed.series.length) === 0)
        return res.json({ ok: false, error: 'empty_library', note: 'nothing parsed — keeping previous snapshot' });
      const enh = clean.enhance(parsed);
      const name = (await pool.query('SELECT name FROM products WHERE slug=$1', [req.params.server])).rows[0];
      await store(req.params.server, name ? name.name : req.params.server, enh);
      res.json({ ok: true, server: req.params.server, counts: enh.counts, raw: enh.rawCounts, adult: enh.adult });
    } catch (e) { res.status(500).json({ ok: false, error: 'ingest_failed', detail: String(e.message || e) }); }
  });

  async function store(server, name, enh) {
    // persist only name/quality/category/country/variants/episodes (no stream URL, no password) — gzipped
    const pack = k => enh[k].items.map(i => [i.name, (i.quality || []).join('/'), i.category, i.country || '', i.flag || '', i.variants, i.episodes || 0]);
    const items = zlib.gzipSync(Buffer.from(JSON.stringify({ live: pack('live'), vod: pack('vod'), series: pack('series') })));
    const cats = { live: { categories: enh.live.categories, countries: enh.live.countries }, vod: { categories: enh.vod.categories, countries: enh.vod.countries }, series: { categories: enh.series.categories, countries: enh.series.countries } };
    await pool.query(
      `INSERT INTO iptv_library(server_key,name,live_count,vod_count,series_count,episode_count,raw_live,raw_vod,raw_series,categories,items,adult_hidden,status,updated_at)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'ok',now())
       ON CONFLICT (server_key) DO UPDATE SET
         name=$2,live_count=$3,vod_count=$4,series_count=$5,episode_count=$6,
         raw_live=$7,raw_vod=$8,raw_series=$9,categories=$10,items=$11,adult_hidden=$12,status='ok',updated_at=now()`,
      [server, name, enh.counts.live, enh.counts.vod, enh.counts.series, enh.counts.episodes,
       enh.rawCounts.live, enh.rawCounts.vod, enh.rawCounts.series, JSON.stringify(cats), items, enh.adult]);
  }

  // Public per-server summary (counts + categories) for the "What's Inside" display.
  router.get('/iptv/:server/summary.json', async (req, res) => {
    try {
      const r = (await pool.query(
        `SELECT server_key, name, live_count, vod_count, series_count, episode_count, categories, adult_hidden, updated_at
           FROM iptv_library WHERE server_key=$1`, [req.params.server])).rows[0];
      if (!r) return res.status(404).json({ ok: false, error: 'not_found' });
      res.json({ ok: true, server: r });
    } catch (e) { res.status(500).json({ ok: false }); }
  });

  // The phone agent script (served with BASE + KEY baked in, so the phone setup is a 3-line paste
   // and updates never need re-pasting on the device). One cycle: list servers → per server resolve
   // the M3U link, download it on the phone's residential connection, gzip, push it back.
  // Pure curl + grep/sed (no jq) so it runs on a bare Termux. One cycle: list servers → per server
  // resolve the M3U link, download it on the phone's residential connection, gzip, push it back.
  const AGENT = [
    '#!/data/data/com.termux/files/usr/bin/env sh',
    '# GSZ IPTV agent — self-looping. Each sweep pulls only the servers that still need data',
    '# (missing / empty / stale), pushing each full library to GSZ. Free, automatic, self-healing.',
    'BASE="__BASE__"', 'KEY="__KEY__"',
    'INTERVAL=7200   # seconds between sweeps (2h)',
    'TMP="$HOME/.gsz-iptv"; mkdir -p "$TMP"',
    'ts(){ date "+%H:%M:%S"; }',
    'termux-wake-lock 2>/dev/null || true',
    '# pull one panel: $1=server $2=sku $3=extra query (&fresh=1). 0=pushed, 1=empty, 2=no link',
    'pull(){',
    '  M3U=$(curl -s --max-time 200 "$BASE/internal/iptv/url/$2?key=$KEY$3" | grep -o \'"m3u_url":"[^"]*"\' | sed \'s/"m3u_url":"//; s/"$//\')',
    '  [ -z "$M3U" ] && { echo "$(ts) [$1] no order/trial available yet — skipping"; return 2; }',
    '  curl -s --max-time 1800 --compressed -o "$TMP/lib.m3u" "$M3U"',
    '  SZ=$(wc -c < "$TMP/lib.m3u" 2>/dev/null || echo 0)',
    '  if [ "${SZ:-0}" -lt 1000 ]; then echo "$(ts) [$1] empty download (${SZ}b): $(head -c 100 "$TMP/lib.m3u" 2>/dev/null | tr -d "\\n")"; return 1; fi',
    '  echo "$(ts) [$1] pushing (${SZ}b)…"',
    '  RESP=$(gzip -c "$TMP/lib.m3u" | curl -s --max-time 600 -X POST -H "x-iptv-key: $KEY" -H "Content-Type: application/octet-stream" --data-binary @- "$BASE/internal/iptv/ingest/$1")',
    '  echo "$(ts) [$1] $RESP"; rm -f "$TMP/lib.m3u"; return 0',
    '}',
    'echo "$(ts) sweep starting — checking which servers need data"',
    'LIST=$(curl -s --max-time 30 "$BASE/internal/iptv/servers?key=$KEY&stale=1" | grep -o \'"server":"[^"]*","sku":"[^"]*"\' | sed \'s/"server":"\\([^"]*\\)","sku":"\\([^"]*\\)"/\\1 \\2/\')',
    'if [ -z "$LIST" ]; then echo "$(ts) all servers fresh — nothing to pull this sweep";',
    'else echo "$LIST" | while read SERVER SKU; do',
    '  [ -z "$SERVER" ] && continue',
    '  echo "$(ts) [$SERVER] resolving link…"',
    '  pull "$SERVER" "$SKU" ""; rc=$?',
    '  if [ "$rc" = "1" ]; then echo "$(ts) [$SERVER] retrying with a fresh order/trial…"; pull "$SERVER" "$SKU" "&fresh=1"; fi',
    '  sleep 3',
    'done; fi',
    'echo "$(ts) sweep done — self-updating + sleeping ${INTERVAL}s"',
    'curl -s --max-time 30 "$BASE/internal/iptv/agent.sh?key=$KEY" -o "$HOME/gsz-iptv.sh" 2>/dev/null',
    'sleep "$INTERVAL"',
    'exec sh "$HOME/gsz-iptv.sh"'
  ].join('\n');
  router.get('/internal/iptv/agent.sh', auth, (req, res) => {
    const base = (process.env.SITE_BASE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '');
    res.type('text/plain').send(AGENT.replace(/__BASE__/g, base).replace(/__KEY__/g, KEY) + '\n');
  });

  // ---- "What's Inside" display: decompressed-items cache + browse API + premium pages ----
  const _items = {};
  async function loadItems(server) {
    const c = _items[server];
    if (c && (Date.now() - c.at) < 5 * 60 * 1000) return c.data;
    const r = (await pool.query('SELECT items FROM iptv_library WHERE server_key=$1', [server])).rows[0];
    if (!r || !r.items) return null;
    let data; try { data = JSON.parse(zlib.gunzipSync(r.items).toString()); } catch (e) { return null; }
    _items[server] = { data, at: Date.now() };
    return data;
  }
  router.get('/iptv/:server/browse.json', async (req, res) => {
    try {
      const type = ['live', 'vod', 'series'].includes(req.query.type) ? req.query.type : 'live';
      const data = await loadItems(req.params.server);
      if (!data) return res.status(404).json({ ok: false, error: 'not_ready' });
      const q = String(req.query.q || '').trim().toLowerCase();
      const cat = String(req.query.cat || '').trim();
      const page = Math.max(1, parseInt(req.query.page, 10) || 1);
      const size = Math.min(100, Math.max(10, parseInt(req.query.size, 10) || 48));
      const country = String(req.query.country || '').trim();
      let rows = data[type] || [];
      const isNew = rows.length > 0 && rows[0].length >= 7; // new: [name,q,cat,country,flag,variants,eps]; old: [name,q,cat,variants,eps]
      if (cat) rows = rows.filter(r => r[2] === cat);
      if (country && isNew) rows = rows.filter(r => r[3] === country);
      if (q) rows = rows.filter(r => String(r[0]).toLowerCase().indexOf(q) >= 0);
      const total = rows.length;
      const items = rows.slice((page - 1) * size, page * size).map(r => isNew
        ? { name: r[0], quality: r[1], category: r[2], country: r[3], flag: r[4], variants: r[5], episodes: r[6] }
        : { name: r[0], quality: r[1], category: r[2], variants: r[3], episodes: r[4] });
      res.json({ ok: true, type, total, page, size, pages: Math.ceil(total / size), items });
    } catch (e) { res.status(500).json({ ok: false }); }
  });
  router.get('/library', async (req, res) => {
    try {
      const rows = (await pool.query(
        `SELECT server_key,name,live_count,vod_count,series_count,episode_count,raw_live,raw_vod,raw_series
           FROM iptv_library WHERE status='ok' AND (live_count+vod_count+series_count)>0
          ORDER BY (raw_live+raw_vod+raw_series) DESC`)).rows;
      res.type('html').send(pages.libraryIndexHtml(rows, ''));
    } catch (e) { res.status(500).send('error'); }
  });
  router.get('/library/:server', async (req, res) => {
    try {
      const r = (await pool.query(
        `SELECT server_key,name,live_count,vod_count,series_count,episode_count,
                raw_live,raw_vod,raw_series,categories,updated_at
           FROM iptv_library WHERE server_key=$1`, [req.params.server])).rows[0];
      if (!r) return res.status(404).send('<p style="font:16px system-ui;padding:40px">This server is still importing — check back soon.</p>');
      res.type('html').send(pages.serverExplorerHtml(r, ''));
    } catch (e) { res.status(500).send('error'); }
  });

  // Overall library status (for the admin + the phone to see what's fresh).
  router.get('/internal/iptv/status', auth, async (req, res) => {
    try {
      const rows = (await pool.query(
        `SELECT server_key, name, live_count, vod_count, series_count, episode_count, status, updated_at
           FROM iptv_library ORDER BY updated_at DESC NULLS LAST`)).rows;
      res.json({ ok: true, servers: rows });
    } catch (e) { res.status(500).json({ ok: false }); }
  });

  return router;
};
