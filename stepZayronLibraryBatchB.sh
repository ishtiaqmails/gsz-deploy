#!/usr/bin/env bash
# stepZayronLibraryBatchB — zayron shows galaxyzayron's live library counts on cards/pages/tokens.
#  - new lib/gszLibrary.js reads gsz iptv_library (via /opt/gsz/.env, read-only), matched by normalized name
#  - lib/data.js overrides each server's ch/vod/series with galaxyzayron's counts
#  - routes/admin.js drops the "Card numbers" nav item
# Safe: backup, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp lib/data.js "$B/"; cp routes/admin.js "$B/"
[ -f lib/gszLibrary.js ] && cp lib/gszLibrary.js "$B/" || true
revert(){ cp "$B/data.js" lib/data.js; cp "$B/admin.js" routes/admin.js; [ -f "$B/gszLibrary.js" ] && cp "$B/gszLibrary.js" lib/gszLibrary.js || rm -f lib/gszLibrary.js; pm2 restart zayron >/dev/null 2>&1 || true; }

# ---- new library reader ----
cat > lib/gszLibrary.js <<'LIB'
'use strict';
// lib/gszLibrary.js — read galaxyzayron's iptv_library (live counts) and match to zayron servers by name.
// Read-only pool built from /opt/gsz/.env (same cross-app pattern as paySalt). Cached 15 min.
const { Pool } = require('pg');
const fs = require('fs');
let _gp = null;
function gpool() {
  if (_gp) return _gp;
  let env = {};
  try {
    fs.readFileSync('/opt/gsz/.env', 'utf8').split(/\r?\n/).forEach(function (l) {
      var m = l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/i);
      if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '').trim();
    });
  } catch (e) { return null; }
  if (!env.DB_NAME) return null;
  _gp = new Pool({ host: env.DB_HOST || '127.0.0.1', port: Number(env.DB_PORT || 5432), user: env.DB_USER, password: env.DB_PASS, database: env.DB_NAME, max: 2, connectionTimeoutMillis: 5000, idleTimeoutMillis: 15000, options: '-c default_transaction_read_only=on' });
  _gp.on('error', function () {});
  return _gp;
}
function norm(s) { return String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '').replace(/iptv|ott|tv/g, ''); }
let _cache = { at: 0, list: [] };
const TTL = 15 * 60 * 1000;
async function load() {
  if (Date.now() - _cache.at < TTL && _cache.list.length) return _cache.list;
  const gp = gpool();
  if (!gp) return _cache.list;
  try {
    const r = await gp.query('SELECT server_key, name, live_count, vod_count, series_count FROM iptv_library');
    _cache = { at: Date.now(), list: r.rows.map(function (x) { return { nk: norm(x.name), ns: norm(x.server_key), live: Number(x.live_count) || 0, vod: Number(x.vod_count) || 0, series: Number(x.series_count) || 0 }; }) };
  } catch (e) {}
  return _cache.list;
}
function countsFor(list, sv) {
  if (!list || !list.length) return null;
  var ns = norm(sv.slug), nn = norm(sv.n || sv.name);
  var hit = null, i;
  for (i = 0; i < list.length; i++) { if ((ns && list[i].ns === ns) || (nn && list[i].nk === nn)) { hit = list[i]; break; } }
  if (!hit) { for (i = 0; i < list.length; i++) { var x = list[i]; if ((x.nk && nn && (x.nk.indexOf(nn) === 0 || nn.indexOf(x.nk) === 0)) || (x.ns && ns && (x.ns.indexOf(ns) === 0 || ns.indexOf(x.ns) === 0))) { hit = x; break; } } }
  if (!hit) return null;
  return { live: hit.live, vod: hit.vod, series: hit.series };
}
module.exports = { load, countsFor };
LIB

T="$(mktemp -d)"
# ---- data.js: inject galaxyzayron counts ----
cat > "$T/d_o" <<'O'
  SERVERS.forEach(sv => {
    const c = chCounts[sv.id] || {};
    sv.chanCount = (c.live || 0) + (c.movie || 0) + (c.series || 0);
    sv.liveCount = c.live || 0;
    sv.movieCount = c.movie || 0;
    sv.seriesCount = (c.shows != null ? c.shows : c.series) || 0;
  });
O
cat > "$T/d_n" <<'O'
  SERVERS.forEach(sv => {
    const c = chCounts[sv.id] || {};
    sv.chanCount = (c.live || 0) + (c.movie || 0) + (c.series || 0);
    sv.liveCount = c.live || 0;
    sv.movieCount = c.movie || 0;
    sv.seriesCount = (c.shows != null ? c.shows : c.series) || 0;
  });
  // LIBRARY SYNC — show galaxyzayron's live counts so both sites match
  try {
    const _gszLib = require('./gszLibrary');
    const _lib = await _gszLib.load();
    if (_lib && _lib.length) {
      for (const sv of SERVERS) {
        const _c = _gszLib.countsFor(_lib, sv);
        if (_c) { sv.ch = niceNum(_c.live); sv.vod = niceNum(_c.vod); sv.series = niceNum(_c.series); sv.liveCount = _c.live; sv.movieCount = _c.vod; sv.seriesCount = _c.series; }
      }
    }
  } catch (e) {}
O

# ---- admin.js: drop "Card numbers" nav item ----
cat > "$T/a_o" <<'O'
      ['/admin/channels/paste','Paste a list','⎘'],
      ['/admin/channels/counts','Card numbers','#']] },
O
cat > "$T/a_n" <<'O'
      ['/admin/channels/paste','Paste a list','⎘']] },
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('lib/data.js', [['d_o','d_n']]);
patch('routes/admin.js', [['a_o','a_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check lib/gszLibrary.js && node --check lib/data.js && node --check routes/admin.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "--- sample counts now (5G Zain / filex / b1g) ---"
node -e "const d=require('./lib/data');d.getPublicData().then(x=>{(x.servers||[]).filter(s=>/zain|filex|b1g/i.test(s.slug)).forEach(s=>console.log(s.slug,'|',s.ch,'/',s.vod,'/',s.series));process.exit(0)}).catch(e=>{console.log(e.message);process.exit(0)})"
echo "DONE: cards/pages show galaxyzayron live counts; Card numbers page removed. healthz=200"
