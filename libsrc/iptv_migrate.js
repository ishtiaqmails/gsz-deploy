'use strict';
/* IPTV Library Engine — storage migration. One compact row per server (counts, category breakdown,
   and a gzipped snapshot of the cleaned name/quality/category list — never a stream URL or password).
   Also prints the self-aware server list the engine will refresh (live from the catalog). */
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

(async () => {
  await pool.query(`CREATE TABLE IF NOT EXISTS iptv_library(
    server_key TEXT PRIMARY KEY,
    name TEXT,
    live_count INT DEFAULT 0, vod_count INT DEFAULT 0, series_count INT DEFAULT 0, episode_count INT DEFAULT 0,
    raw_live INT DEFAULT 0, raw_vod INT DEFAULT 0, raw_series INT DEFAULT 0,
    categories JSONB, items BYTEA, adult_hidden INT DEFAULT 0,
    status TEXT DEFAULT 'pending', updated_at TIMESTAMPTZ DEFAULT now())`);
  console.log('iptv_library table ready');

  // one-time re-process trigger: when the engine version bumps, mark every panel stale so the worker
  // re-pulls once with the new categorisation/country logic. Runs ONCE per version, not every deploy.
  await pool.query(`CREATE TABLE IF NOT EXISTS iptv_meta(k text primary key, v text)`);
  const ENGINE_VER = '3-clean';
  const cur = (await pool.query("SELECT v FROM iptv_meta WHERE k='engine_ver'")).rows[0];
  if (!cur || cur.v !== ENGINE_VER) {
    const n = (await pool.query("UPDATE iptv_library SET updated_at = now() - interval '2 days'")).rowCount;
    await pool.query("INSERT INTO iptv_meta(k,v) VALUES('engine_ver',$1) ON CONFLICT (k) DO UPDATE SET v=$1", [ENGINE_VER]);
    console.log('engine upgraded to ' + ENGINE_VER + ' — marked ' + n + ' panels for one-time re-process');
  }

  const rows = (await pool.query(
    `SELECT DISTINCT p.slug, p.name, pp.bot_sku AS sku
       FROM products p
       JOIN categories c ON c.id = p.category_id
       JOIN product_plans pp ON pp.product_id = p.id
      WHERE c.slug = 'iptv' AND p.active AND NOT p.hidden
        AND pp.bot_sku IS NOT NULL AND pp.bot_sku <> ''
      ORDER BY p.name`)).rows;
  const seen = new Set(); let n = 0;
  console.log('--- self-aware IPTV server list (live from your catalog) ---');
  rows.forEach(r => { if (!seen.has(r.sku)) { seen.add(r.sku); n++; console.log('  ' + r.sku + '  ' + r.slug + '  (' + r.name + ')'); } });
  console.log(n + ' IPTV servers discovered');
  await pool.end();
  console.log('MIGRATE OK');
})().catch(e => { console.error('FAIL ' + e.message); process.exit(1); });
