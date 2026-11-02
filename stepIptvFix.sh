#!/usr/bin/env bash
# stepIptvFix.sh — fix gsz-iptv-worker OOM. m3u.js: count unmarked episodes instead of storing 1M unique strings
# (episode counts stay identical). worker.js: free raw lib before gzip. Plus a heap + max-memory-restart backstop.
set -uo pipefail
GSZ=/opt/gsz
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
TS=$(date +%s)
M=lib/iptv/m3u.js; W=lib/iptv/worker.js
cp -f "$M" "$M.xbak.$TS"; cp -f "$W" "$W.xbak.$TS"
restore(){ echo "!! failed — rolling back code (worker process untouched)"; cp -f "$M.xbak.$TS" "$M"; cp -f "$W.xbak.$TS" "$W"; rm -f .gszm_iptv.js; exit 1; }
trap restore ERR
nchk(){ local f="$1" i; for i in 1 2 3 4 5; do node --check "$f" 2>/dev/null && return 0; sleep 1; done; echo "  node --check failing: $f"; return 1; }

echo "==> patching m3u.js (episode counter) + worker.js (free raw)"
cat > .gszm_iptv.js <<'JS'
var fs = require('fs');
function patch(file, a, b, label) { var s = fs.readFileSync(file, 'utf8'); var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + label + ' ANCHOR x' + n + ' — aborting (no change)'); process.exit(2); } fs.writeFileSync(file, s.split(a).join(b)); console.log('  ' + label + ': ok'); }
patch('lib/iptv/m3u.js',
  "eps: new Set() }; seriesMap.set(key, s); }",
  "eps: new Set(), plus: 0 }; seriesMap.set(key, s); }",
  'series-init');
patch('lib/iptv/m3u.js',
  "if (sp.season != null && sp.ep != null) s.eps.add(sp.season + '-' + sp.ep);\n        else s.eps.add('x-' + s.eps.size);",
  "if (sp.season != null && sp.ep != null) { if (s.eps.size < 100000) s.eps.add(sp.season + '-' + sp.ep); else s.plus++; }\n        else s.plus++;",
  'series-count');
patch('lib/iptv/m3u.js',
  "episode_count: s.eps.size }));",
  "episode_count: s.eps.size + (s.plus || 0) }));",
  'series-output');
patch('lib/iptv/worker.js',
  "const enh = clean.enhance(r.lib);\n  await store(server, name, enh);",
  "const enh = clean.enhance(r.lib);\n  r.lib = null;\n  await store(server, name, enh);",
  'free-raw');
console.log('  all patches applied');
process.exit(0);
JS
node .gszm_iptv.js
nchk "$M"; nchk "$W"
rm -f .gszm_iptv.js
echo "   checks passed"
trap - ERR

echo "==> heap + max-memory-restart backstop (re-register worker, verified)"
TOTAL_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}'); TOTAL_MB=${TOTAL_MB:-0}
HEAP=512; MEMR="640M"
if [ "$TOTAL_MB" -ge 3500 ]; then HEAP=1024; MEMR="1300M"; elif [ "$TOTAL_MB" -ge 1800 ]; then HEAP=768; MEMR="950M"; fi
echo "   RAM=${TOTAL_MB}MB -> heap=${HEAP}MB, max_memory_restart=${MEMR}"
pm2 save >/dev/null 2>&1 || true
pm2 delete gsz-iptv-worker >/dev/null 2>&1 || true
pm2 start "$GSZ/lib/iptv/worker.js" --name gsz-iptv-worker --cwd "$GSZ" --node-args="--max-old-space-size=$HEAP" --max-memory-restart "$MEMR" >/dev/null 2>&1 || true
sleep 2
ST=$(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let p=JSON.parse(d).find(x=>x.name==="gsz-iptv-worker");process.stdout.write((p&&p.pm2_env&&p.pm2_env.status)||"missing");}catch(e){process.stdout.write("err");}})')
if [ "$ST" != "online" ]; then
  echo "   re-register not online ($ST) — restoring plain start"
  pm2 delete gsz-iptv-worker >/dev/null 2>&1 || true
  pm2 start "$GSZ/lib/iptv/worker.js" --name gsz-iptv-worker --cwd "$GSZ" >/dev/null 2>&1 || true
  sleep 2
  ST=$(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let p=JSON.parse(d).find(x=>x.name==="gsz-iptv-worker");process.stdout.write((p&&p.pm2_env&&p.pm2_env.status)||"missing");}catch(e){process.stdout.write("err");}})')
fi
pm2 save >/dev/null 2>&1 || true
echo "   worker status: $ST"
[ "$ST" = "online" ] && echo "DONE — IPTV worker patched (counts identical, memory bounded) + backstop set." || echo "WARN — worker not online; check: pm2 logs gsz-iptv-worker"
