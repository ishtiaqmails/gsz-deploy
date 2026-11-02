#!/usr/bin/env bash
# stepLibNoRegress.sh — worker store(): never overwrite a richer snapshot (has vod/series) with a poorer one (live-only).
set -uo pipefail
GSZ=/opt/gsz
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
TS=$(date +%s)
W=lib/iptv/worker.js
cp -f "$W" "$W.xbak.$TS"
restore(){ echo "!! failed — rolling back worker.js"; cp -f "$W.xbak.$TS" "$W"; rm -f .gszm_nr.js; exit 1; }
trap restore ERR
nchk(){ local i; for i in 1 2 3 4 5; do node --check "$W" 2>/dev/null && return 0; sleep 1; done; echo "  node --check failing"; return 1; }

echo "==> adding no-regress guard to store() INSERT ... ON CONFLICT"
cat > .gszm_nr.js <<'JS'
var fs = require('fs');
var W = 'lib/iptv/worker.js';
var s = fs.readFileSync(W, 'utf8');
var a = "adult_hidden=$12,status='ok',updated_at=now()`";
var b = "adult_hidden=$12,status='ok',updated_at=now()\n     WHERE ($4 + $5) > 0 OR (iptv_library.vod_count + iptv_library.series_count) = 0`";
var n = s.split(a).length - 1;
if (n !== 1) { console.log('  ANCHOR x' + n + ' — aborting (no change)'); process.exit(2); }
s = s.split(a).join(b);
fs.writeFileSync(W, s);
console.log('  guard added');
process.exit(0);
JS
node .gszm_nr.js
nchk
rm -f .gszm_nr.js
echo "   node check ok"
trap - ERR

echo "==> restart worker + verify online"
pm2 restart gsz-iptv-worker >/dev/null 2>&1; sleep 2
ST=$(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let p=JSON.parse(d).find(x=>x.name==="gsz-iptv-worker");process.stdout.write((p&&p.pm2_env&&p.pm2_env.status)||"missing");}catch(e){process.stdout.write("err");}})')
echo "   worker status: $ST"
[ "$ST" = "online" ] && echo "DONE — live-only pulls can no longer clobber a fuller library snapshot." || echo "WARN — worker not online; check: pm2 logs gsz-iptv-worker"
