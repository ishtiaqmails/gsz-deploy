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

module.exports = function (pool) {
  const router = express.Router();
  const KEY = process.env.IPTV_INGEST_KEY || '';

  function auth(req, res, next) {
    const k = req.get('x-iptv-key') || req.query.key || '';
    if (!KEY || k !== KEY) return res.status(401).json({ ok: false, error: 'unauthorized' });
    next();
  }

  // Self-aware list of IPTV servers to refresh: every active IPTV product + its bot sku.
  router.get('/internal/iptv/servers', auth, async (req, res) => {
    try {
      const rows = (await pool.query(
        `SELECT DISTINCT p.slug, p.name, pp.bot_sku AS sku
           FROM products p
           JOIN categories c ON c.id = p.category_id
           JOIN product_plans pp ON pp.product_id = p.id
          WHERE c.slug = 'iptv' AND p.active AND NOT p.hidden
            AND pp.bot_sku IS NOT NULL AND pp.bot_sku <> ''
          ORDER BY p.name`)).rows;
      const seen = new Set(), servers = [];
      rows.forEach(r => { if (!seen.has(r.sku)) { seen.add(r.sku); servers.push({ server: r.slug, sku: r.sku, name: r.name }); } });
      res.json({ ok: true, servers });
    } catch (e) { res.status(500).json({ ok: false, error: 'server_list_failed', detail: String(e.message || e) }); }
  });

  // Resolve a fresh read-only M3U url for one sku (creds via order/trial, cached server-side).
  router.get('/internal/iptv/url/:sku', auth, async (req, res) => {
    try {
      const cr = await credsource.resolve(req.params.sku, { hours: 24, trialTimeoutMs: 150000 });
      if (!cr.ok) return res.json({ ok: false, error: cr.error, detail: cr.detail });
      const base = String(cr.host).replace(/\/+$/, '');
      const url = base + '/get.php?username=' + encodeURIComponent(cr.username) + '&password=' + encodeURIComponent(cr.password) + '&type=m3u_plus&output=ts';
      res.json({ ok: true, source: cr.source, m3u_url: url, dns: cr.host });
    } catch (e) { res.status(500).json({ ok: false, error: 'resolve_failed', detail: String(e.message || e) }); }
  });

  // Receive a pushed M3U (raw body, optionally gzipped) → clean → store. octet-stream content-type
  // so no global json/urlencoded parser touches the binary body.
  router.post('/internal/iptv/ingest/:server', auth, express.raw({ type: () => true, limit: '120mb' }), async (req, res) => {
    try {
      let buf = req.body;
      if (!Buffer.isBuffer(buf) || !buf.length) return res.status(400).json({ ok: false, error: 'empty_body' });
      const enc = (req.get('content-encoding') || '').toLowerCase();
      if (enc === 'gzip' || (buf.length > 2 && buf[0] === 0x1f && buf[1] === 0x8b)) { try { buf = zlib.gunzipSync(buf); } catch (e) {} }
      const parsed = await m3u.parseM3UString(buf.toString('utf8'));
      if (!parsed || !parsed.ok) return res.status(400).json({ ok: false, error: 'parse_failed' });
      const enh = clean.enhance(parsed);
      const name = (await pool.query('SELECT name FROM products WHERE slug=$1', [req.params.server])).rows[0];
      await store(req.params.server, name ? name.name : req.params.server, enh);
      res.json({ ok: true, server: req.params.server, counts: enh.counts, raw: enh.rawCounts, adult: enh.adult });
    } catch (e) { res.status(500).json({ ok: false, error: 'ingest_failed', detail: String(e.message || e) }); }
  });

  async function store(server, name, enh) {
    // persist only name/quality/category/variants/episodes (no stream URL, no password) — gzipped
    const pack = k => enh[k].items.map(i => [i.name, (i.quality || []).join('/'), i.category, i.variants, i.episodes || 0]);
    const items = zlib.gzipSync(Buffer.from(JSON.stringify({ live: pack('live'), vod: pack('vod'), series: pack('series') })));
    const cats = { live: enh.live.categories, vod: enh.vod.categories, series: enh.series.categories };
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
