#!/usr/bin/env bash
# stepLibLog.sh — IPTV library tracing foundation: log table + last_source/last_via, wired into BOTH store() paths.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
W=lib/iptv/worker.js; R=routes/iptv.js
cp -f "$W" "$W.xbak.$TS"; cp -f "$R" "$R.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$W.xbak.$TS" "$W"; cp -f "$R.xbak.$TS" "$R"; rm -f .mig.js .ow.txt .nw.txt .or.txt .nr.txt .pp.js; exit 1; }
trap restore ERR
nchk(){ local f="$1" i; for i in 1 2 3 4 5; do node --check "$f" 2>/dev/null && return 0; sleep 1; done; echo "  node --check failing: $f"; return 1; }

echo "==> migration: iptv_library_log + last_source/last_via"
cat > .mig.js <<'JS'
require('/opt/gsz/node_modules/dotenv').config({ path: '/opt/gsz/.env' });
const { Pool } = require('/opt/gsz/node_modules/pg');
const p = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
(async () => {
  try {
    await p.query("ALTER TABLE iptv_library ADD COLUMN IF NOT EXISTS last_source text");
    await p.query("ALTER TABLE iptv_library ADD COLUMN IF NOT EXISTS last_via text");
    await p.query("CREATE TABLE IF NOT EXISTS iptv_library_log (id bigserial PRIMARY KEY, server_key text NOT NULL, source text, via text, live_count int, vod_count int, series_count int, episode_count bigint, status text NOT NULL DEFAULT 'ok', note text, created_at timestamptz NOT NULL DEFAULT now())");
    await p.query("CREATE INDEX IF NOT EXISTS iptv_library_log_srv_idx ON iptv_library_log(server_key, created_at DESC)");
    console.log('  migration ok');
  } catch (e) { console.log('  migration err: ' + e.message); process.exit(3); }
  await p.end();
})();
JS
node .mig.js

echo "==> wiring worker.js + routes/iptv.js (both store paths)"
cat > .ow.txt <<'OLDS'
async function store(server, name, enh) {
@@@
items, enh.adult]);
@@@
await store(server, name, enh);
@@@
if (!r.ok) return { server, fail: r.err || cr.error, api: r.api };
OLDS
cat > .nw.txt <<'NEWS'
async function store(server, name, enh, source, via) {
@@@
items, enh.adult]); try { await pool.query("UPDATE iptv_library SET last_source=$2,last_via=$3 WHERE server_key=$1",[server,source||null,via||null]); } catch(e){} try { await pool.query("INSERT INTO iptv_library_log(server_key,source,via,live_count,vod_count,series_count,episode_count,status) VALUES($1,$2,$3,$4,$5,$6,$7,'ok')",[server,source||null,via||null,enh.counts.live,enh.counts.vod,enh.counts.series,enh.counts.episodes]); } catch(e){}
@@@
await store(server, name, enh, src, r.via);
@@@
if (!r.ok) { try { await pool.query("INSERT INTO iptv_library_log(server_key,source,via,status,note) VALUES($1,$2,$3,'fail',$4)",[server,src,null,String(r.err||cr.error||'').slice(0,200)]); } catch(e){} return { server, fail: r.err || cr.error, api: r.api }; }
NEWS

cat > .or.txt <<'OLDS'
async function store(server, name, enh) {
@@@
items, enh.adult]);
@@@
await store(req.params.server, name ? name.name : req.params.server, enh);
OLDS
cat > .nr.txt <<'NEWS'
async function store(server, name, enh, source, via) {
@@@
items, enh.adult]); try { await pool.query("UPDATE iptv_library SET last_source=$2,last_via=$3 WHERE server_key=$1",[server,source||null,via||null]); } catch(e){} try { await pool.query("INSERT INTO iptv_library_log(server_key,source,via,live_count,vod_count,series_count,episode_count,status) VALUES($1,$2,$3,$4,$5,$6,$7,'ok')",[server,source||null,via||null,enh.counts.live,enh.counts.vod,enh.counts.series,enh.counts.episodes]); } catch(e){}
@@@
await store(req.params.server, name ? name.name : req.params.server, enh, 'phone', 'ingest');
NEWS

cat > .pp.js <<'JS'
var fs = require('fs');
function apply(file, ofile, nfile) {
  var olds = fs.readFileSync(ofile, 'utf8').replace(/\n$/, '').split('\n@@@\n');
  var news = fs.readFileSync(nfile, 'utf8').replace(/\n$/, '').split('\n@@@\n');
  if (olds.length !== news.length) { console.log('  ' + file + ' pair count mismatch'); process.exit(2); }
  var s = fs.readFileSync(file, 'utf8');
  for (var k = 0; k < olds.length; k++) { var a = olds[k], b = news[k]; var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + file + ' pair ' + (k + 1) + ' x' + n + ' :: ' + a.slice(0, 45)); process.exit(2); } s = s.split(a).join(b); }
  fs.writeFileSync(file, s); console.log('  ' + file + ': ' + olds.length + ' edits ok');
}
apply('lib/iptv/worker.js', '.ow.txt', '.nw.txt');
apply('routes/iptv.js', '.or.txt', '.nr.txt');
process.exit(0);
JS
node .pp.js
nchk "$W"; nchk "$R"
rm -f .mig.js .ow.txt .nw.txt .or.txt .nr.txt .pp.js
echo "   checks passed"
trap - ERR

echo "==> restart worker + site + health"
pm2 restart gsz-iptv-worker >/dev/null 2>&1
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "$W.xbak.$TS" "$W"; cp -f "$R.xbak.$TS" "$R"; pm2 restart gsz-iptv-worker >/dev/null 2>&1; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
echo "DONE — every library update now records source/via + a history row."
