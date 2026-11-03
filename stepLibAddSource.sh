#!/usr/bin/env bash
# stepLibAddSource.sh — Phase 1: add any IPTV by pasting an M3U link or Xtream login; server pulls it.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
A=routes/adminIptv.js; V=views/admin/iptv.ejs
cp -f "$A" "$A.xbak.$TS"; cp -f "$V" "$V.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$A.xbak.$TS" "$A"; cp -f "$V.xbak.$TS" "$V"; rm -f lib/iptv/pull.js .mig.js .pj.js; exit 1; }
trap restore ERR

echo "==> migration: iptv_manual_sources"
cat > .mig.js <<'JS'
require('/opt/gsz/node_modules/dotenv').config({ path: '/opt/gsz/.env' });
const { Pool } = require('/opt/gsz/node_modules/pg');
const p = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
(async () => { try {
  await p.query("CREATE TABLE IF NOT EXISTS iptv_manual_sources (id bigserial PRIMARY KEY, server_key text UNIQUE NOT NULL, name text NOT NULL, kind text NOT NULL DEFAULT 'm3u', m3u_url text, host text, username text, password text, active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now())");
  console.log('  migration ok');
} catch (e) { console.log('  migration err ' + e.message); process.exit(3); } await p.end(); })();
JS
node .mig.js

echo "==> lib/iptv/pull.js (shared pull+store for a manual source)"
cat > lib/iptv/pull.js <<'PULL'
'use strict';
const zlib = require('zlib');
const m3u = require('./m3u');
const clean = require('./clean');
const fetch = require('./fetch');

function fromXtream(x) {
  const map = (arr, cats) => (arr || []).map(r => ({ name: r.name || r.title || '', category_name: (cats || {})[String(r.category_id)] || '', stream_icon: r.stream_icon || r.cover || '' }));
  return { ok: true, live: map(x.live, x.liveCats), vod: map(x.vod, x.vodCats), series: (x.series || []).map(r => ({ name: r.name || r.title || '', category_name: (x.seriesCats || {})[String(r.category_id)] || '', cover: r.cover || '', episode_count: 0 })) };
}

async function store(pool, server, name, enh, source, via) {
  const pack = k => enh[k].items.map(i => [i.name, (i.quality || []).join('/'), i.category, i.country || '', i.flag || '', i.variants, i.episodes || 0]);
  const items = zlib.gzipSync(Buffer.from(JSON.stringify({ live: pack('live'), vod: pack('vod'), series: pack('series') })));
  const cats = { live: { categories: enh.live.categories, countries: enh.live.countries }, vod: { categories: enh.vod.categories, countries: enh.vod.countries }, series: { categories: enh.series.categories, countries: enh.series.countries } };
  await pool.query(
    "INSERT INTO iptv_library(server_key,name,live_count,vod_count,series_count,episode_count,raw_live,raw_vod,raw_series,categories,items,adult_hidden,status,updated_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'ok',now()) ON CONFLICT (server_key) DO UPDATE SET name=$2,live_count=$3,vod_count=$4,series_count=$5,episode_count=$6,raw_live=$7,raw_vod=$8,raw_series=$9,categories=$10,items=$11,adult_hidden=$12,status='ok',updated_at=now()",
    [server, name, enh.counts.live, enh.counts.vod, enh.counts.series, enh.counts.episodes, enh.rawCounts.live, enh.rawCounts.vod, enh.rawCounts.series, JSON.stringify(cats), items, enh.adult]);
  try { await pool.query("UPDATE iptv_library SET last_source=$2,last_via=$3 WHERE server_key=$1", [server, source, via]); } catch (e) {}
  try { await pool.query("INSERT INTO iptv_library_log(server_key,source,via,live_count,vod_count,series_count,episode_count,status) VALUES($1,$2,$3,$4,$5,$6,$7,'ok')", [server, source, via, enh.counts.live, enh.counts.vod, enh.counts.series, enh.counts.episodes]); } catch (e) {}
}

async function pullSource(pool, src) {
  let lib, via;
  if (src.kind === 'xtream') {
    const x = await fetch.fetchAll(src.host, src.username, src.password);
    if (((x.live || []).length + (x.vod || []).length + (x.series || []).length) === 0) return { ok: false, error: (x.errors && (x.errors.live || x.errors.vod || x.errors.series)) || 'empty_or_blocked' };
    lib = fromXtream(x); via = 'xtream';
  } else {
    lib = await m3u.fetchM3U(src.m3u_url, 30 * 60 * 1000);
    if (!lib.ok) return { ok: false, error: lib.error || 'fetch_failed' };
    if ((lib.live.length + lib.vod.length + lib.series.length) === 0) return { ok: false, error: 'empty' };
    via = 'm3u';
  }
  const enh = clean.enhance(lib);
  await store(pool, src.server_key, src.name, enh, 'manual', via);
  return { ok: true, counts: enh.counts };
}
module.exports = { pullSource, store, fromXtream };
PULL
node --check lib/iptv/pull.js

echo "==> rewriting routes/adminIptv.js (manual sources: union + add + remove)"
cat > routes/adminIptv.js <<'AJS'
'use strict';
/* Admin — IPTV Library monitor. DB-driven + self-aware. Shows every active IPTV product AND any
   manually-added source (paste M3U / Xtream). Traces counts, source/via, freshness, phone health,
   full history, per-panel re-sync, and add/remove of manual panels. */
const express = require('express');
const pull = require('../lib/iptv/pull');
module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  async function panels() {
    return (await pool.query(
      `WITH src AS (
         SELECT p.slug AS server_key, p.name, false AS manual
           FROM products p JOIN categories c ON c.id=p.category_id
          WHERE c.slug='iptv' AND p.active AND NOT p.hidden
         UNION
         SELECT ms.server_key, ms.name, true AS manual FROM iptv_manual_sources ms WHERE ms.active
       )
       SELECT s.server_key, s.name, bool_or(s.manual) AS manual,
              l.live_count, l.vod_count, l.series_count, l.episode_count,
              l.status, l.updated_at, l.last_source, l.last_via,
              (COALESCE(l.live_count,0)+COALESCE(l.vod_count,0)+COALESCE(l.series_count,0)) AS total,
              CASE WHEN l.updated_at IS NULL THEN NULL ELSE round(EXTRACT(EPOCH FROM (now()-l.updated_at))/3600.0, 1) END AS age_h
         FROM src s LEFT JOIN iptv_library l ON l.server_key=s.server_key
        GROUP BY s.server_key, s.name, l.live_count, l.vod_count, l.series_count, l.episode_count, l.status, l.updated_at, l.last_source, l.last_via
        ORDER BY total DESC NULLS LAST, s.name`)).rows;
  }
  function classify(r) {
    if (r.updated_at == null || Number(r.total) === 0) return 'never';
    if (r.age_h != null && Number(r.age_h) >= 12) return 'stale';
    if (Number(r.vod_count || 0) === 0 || Number(r.series_count || 0) === 0) return 'partial';
    return 'fresh';
  }
  async function recentLog(limit) {
    return (await pool.query("SELECT server_key, source, via, live_count, vod_count, series_count, episode_count, status, note, created_at FROM iptv_library_log ORDER BY id DESC LIMIT $1", [limit || 40])).rows;
  }
  async function phoneHealth() {
    const row = (await pool.query("SELECT created_at FROM iptv_library_log WHERE source='phone' ORDER BY id DESC LIMIT 1")).rows[0];
    const last = row ? row.created_at : null;
    const ageH = last ? ((Date.now() - new Date(last).getTime()) / 3600000) : null;
    const state = last == null ? 'offline' : (ageH < 6 ? 'online' : (ageH < 16 ? 'idle' : 'offline'));
    return { last, ageH, state };
  }

  router.get('/iptv-library', auth, async (req, res) => {
    try {
      const rows = await panels();
      rows.forEach(r => r.state = classify(r));
      const stat = {
        total: rows.length, fresh: rows.filter(r => r.state === 'fresh').length, attention: rows.filter(r => r.state !== 'fresh').length,
        titles: rows.reduce((n, r) => n + (+r.total || 0), 0), live: rows.reduce((n, r) => n + (+r.live_count || 0), 0),
        vod: rows.reduce((n, r) => n + (+r.vod_count || 0), 0), series: rows.reduce((n, r) => n + (+r.series_count || 0), 0),
        episodes: rows.reduce((n, r) => n + (+r.episode_count || 0), 0),
        newest: rows.reduce((a, r) => (r.updated_at && (!a || r.updated_at > a)) ? r.updated_at : a, null)
      };
      res.render('admin/iptv', { active: 'iptv', title: 'IPTV Library', panels: rows, stat, log: await recentLog(40), phone: await phoneHealth() });
    } catch (e) { res.status(500).send('iptv-library error: ' + e.message); }
  });

  router.get('/iptv-library/history.json', auth, async (req, res) => {
    try {
      const srv = String(req.query.server || '').trim();
      const r = srv ? (await pool.query("SELECT server_key,source,via,live_count,vod_count,series_count,episode_count,status,note,created_at FROM iptv_library_log WHERE server_key=$1 ORDER BY id DESC LIMIT 60", [srv])).rows : await recentLog(60);
      res.json({ ok: true, log: r, phone: await phoneHealth() });
    } catch (e) { res.status(500).json({ ok: false }); }
  });

  router.post('/iptv-library/resync', auth, express.urlencoded({ extended: true }), async (req, res) => {
    try {
      const srv = String(req.body.server || '').trim();
      if (!srv) return res.json({ ok: false, error: 'no server' });
      await pool.query("UPDATE iptv_library SET updated_at = now() - interval '2 days' WHERE server_key=$1", [srv]);
      await pool.query("INSERT INTO iptv_library_log(server_key,source,via,status,note) VALUES($1,'admin','resync','queued','manual re-sync requested')", [srv]);
      res.json({ ok: true });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  router.post('/iptv-library/add-source', auth, express.urlencoded({ extended: true }), async (req, res) => {
    try {
      const name = String(req.body.name || '').trim();
      const kind = req.body.kind === 'xtream' ? 'xtream' : 'm3u';
      if (!name) return res.json({ ok: false, error: 'name required' });
      const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || ('src-' + Date.now());
      let m3u_url = null, host = null, username = null, password = null;
      if (kind === 'xtream') {
        host = String(req.body.host || '').trim(); username = String(req.body.username || '').trim(); password = String(req.body.password || '').trim();
        if (!host || !username || !password) return res.json({ ok: false, error: 'host, username and password are required' });
        if (!/^https?:\/\//i.test(host)) host = 'http://' + host;
      } else {
        m3u_url = String(req.body.m3u_url || '').trim();
        if (!/^https?:\/\//i.test(m3u_url)) return res.json({ ok: false, error: 'a valid M3U URL is required' });
      }
      await pool.query("INSERT INTO iptv_manual_sources(server_key,name,kind,m3u_url,host,username,password,active) VALUES($1,$2,$3,$4,$5,$6,$7,true) ON CONFLICT (server_key) DO UPDATE SET name=$2,kind=$3,m3u_url=$4,host=$5,username=$6,password=$7,active=true",
        [slug, name, kind, m3u_url, host, username, password]);
      let r; try { r = await pull.pullSource(pool, { server_key: slug, name, kind, m3u_url, host, username, password }); } catch (e) { r = { ok: false, error: e.message }; }
      if (!r.ok) { try { await pool.query("INSERT INTO iptv_library_log(server_key,source,via,status,note) VALUES($1,'manual',$2,'fail',$3)", [slug, kind, String(r.error || '').slice(0, 200)]); } catch (e) {} }
      res.json({ ok: true, server: slug, pulled: !!r.ok, counts: r.counts || null, pull_error: r.ok ? null : r.error });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  router.post('/iptv-library/remove-source', auth, express.urlencoded({ extended: true }), async (req, res) => {
    try {
      const srv = String(req.body.server || '').trim();
      await pool.query("DELETE FROM iptv_manual_sources WHERE server_key=$1", [srv]);
      res.json({ ok: true });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  return router;
};
AJS
node --check routes/adminIptv.js

echo "==> adding the Add-a-panel form to views/admin/iptv.ejs"
cat > .pj.js <<'PJS'
var fs = require('fs');
var V = 'views/admin/iptv.ejs';
var s = fs.readFileSync(V, 'utf8');
function one(a, b, label) { var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + label + ' anchor x' + n); process.exit(2); } s = s.split(a).join(b); console.log('  ' + label + ': ok'); }
// CSS: append before closing </style> of the first style block
one('  .lib-lsrv{font-weight:700}.lib-lmeta{color:var(--muted);font-size:11.5px}',
`  .lib-lsrv{font-weight:700}.lib-lmeta{color:var(--muted);font-size:11.5px}
  .lib-add{background:#fff;border-radius:16px;padding:16px 18px;margin-bottom:20px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28)}
  .lib-add-t{font-weight:800;font-size:14.5px;margin-bottom:12px}
  .lib-add-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px}
  .lib-add-grid.x3{grid-template-columns:1fr 1fr 1fr}
  .lib-add-grid input,.lib-add-grid select{margin:0;padding:10px 12px;border:1px solid var(--hair);border-radius:10px;font-size:14px;width:100%}
  @media(max-width:620px){.lib-add-grid,.lib-add-grid.x3{grid-template-columns:1fr}}`, 'css');
// FORM: insert before the dcards row
one('<div class="dcards">',
`<div class="lib-add">
  <div class="lib-add-t">Add any IPTV <span class="lib-ph-s">- paste an M3U link or Xtream login; the server pulls it (no phone needed for reachable panels)</span></div>
  <div class="lib-add-grid">
    <select id="addKind" onchange="toggleKind()"><option value="m3u">M3U link</option><option value="xtream">Xtream login</option></select>
    <input id="addName" placeholder="Name (e.g. Lion OTT)">
  </div>
  <div class="lib-add-grid" id="addM3uRow"><input id="addUrl" placeholder="http://panel.xyz/get.php?username=USER&password=PASS&type=m3u_plus&output=ts" style="grid-column:1/-1"></div>
  <div class="lib-add-grid x3" id="addXtRow" style="display:none"><input id="addHost" placeholder="http://panel.xyz:8080"><input id="addUser" placeholder="username"><input id="addPass" placeholder="password"></div>
  <div class="lib-add-grid"><button class="lib-btn" id="addBtn" onclick="addSource()" style="grid-column:1/-1">Add + pull now</button></div>
  <div id="addMsg" class="lib-ph-s"></div>
</div>
<div class="dcards">`, 'form');
// JS: insert before the auto-refresh interval
one('  setInterval(refreshLog,20000);',
`  function toggleKind(){ var k=document.getElementById('addKind').value; document.getElementById('addM3uRow').style.display=(k==='m3u')?'':'none'; document.getElementById('addXtRow').style.display=(k==='xtream')?'':'none'; }
  function addSource(){ var k=document.getElementById('addKind').value; var name=document.getElementById('addName').value.trim(); var msg=document.getElementById('addMsg'); var btn=document.getElementById('addBtn'); if(!name){ msg.textContent='Enter a name'; return; } var body='kind='+k+'&name='+encodeURIComponent(name); if(k==='xtream'){ body+='&host='+encodeURIComponent(document.getElementById('addHost').value.trim())+'&username='+encodeURIComponent(document.getElementById('addUser').value.trim())+'&password='+encodeURIComponent(document.getElementById('addPass').value.trim()); } else { body+='&m3u_url='+encodeURIComponent(document.getElementById('addUrl').value.trim()); } btn.disabled=true; btn.textContent='Pulling...'; msg.textContent='Fetching the library - this can take a minute...'; fetch('/admin/iptv-library/add-source',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:body}).then(function(r){return r.json();}).then(function(j){ btn.disabled=false; btn.textContent='Add + pull now'; if(!j.ok){ msg.textContent='Error: '+(j.error||'failed'); return; } if(j.pulled){ var c=j.counts||{}; msg.textContent='Added + pulled: '+(c.live||0)+' live, '+(c.vod||0)+' VOD, '+(c.series||0)+' series. Refreshing...'; setTimeout(function(){ location.reload(); },1500); } else { msg.textContent='Added, but the server could not reach it ('+(j.pull_error||'blocked')+'). It will be pulled by the phone agent on its next sweep.'; } }).catch(function(){ btn.disabled=false; btn.textContent='Add + pull now'; msg.textContent='Request failed'; }); }
  setInterval(refreshLog,20000);`, 'js');
fs.writeFileSync(V, s);
process.exit(0);
PJS
node .pj.js
node -e "var ejs=require('/opt/gsz/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('views/admin/iptv.ejs','utf8'),{filename:'/opt/gsz/views/admin/iptv.ejs'});console.log('  ejs ok');"
rm -f .mig.js .pj.js
echo "   checks passed"
trap - ERR

echo "==> restart site + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "$A.xbak.$TS" "$A"; cp -f "$V.xbak.$TS" "$V"; rm -f lib/iptv/pull.js; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
echo "DONE — Add any IPTV (paste M3U / Xtream) is live on /admin/iptv-library."
