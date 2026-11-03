#!/usr/bin/env bash
# stepLibClose.sh — add a Close chip to search results + intelligence ranking so they dismiss easily.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
V=views/admin/iptv.ejs
cp -f "$V" "$V.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$V.xbak.$TS" "$V"; rm -f .pj.js; exit 1; }
trap restore ERR

cat > .pj.js <<'PJS'
var fs = require('fs');
var V = 'views/admin/iptv.ejs';
var s = fs.readFileSync(V, 'utf8');
function one(a, b, label) { var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + label + ' x' + n); process.exit(2); } s = s.split(a).join(b); console.log('  ' + label + ': ok'); }

// 1) CSS for the close chip
one('  .lib-cc{display:inline-block;font-size:10.5px;font-weight:700;color:#5a6a8a;background:#f0f3f9;border-radius:999px;padding:1px 7px;margin:1px 3px 1px 0}',
`  .lib-cc{display:inline-block;font-size:10.5px;font-weight:700;color:#5a6a8a;background:#f0f3f9;border-radius:999px;padding:1px 7px;margin:1px 3px 1px 0}
  .lib-clear{display:inline-block;cursor:pointer;font-size:12px;font-weight:700;color:#c0362c;background:#fdeaea;border-radius:999px;padding:4px 12px;margin-bottom:10px;user-select:none}
  .lib-clear:hover{background:#fbdcdc}`, 'css');

// 2) search results: prepend a Close chip
one(`box.innerHTML='<div class="lib-ph-s">'+j.total+(j.capped?'+':'')+' matches</div>'+j.items.map(`,
`box.innerHTML='<div class="lib-clear" onclick="clearSearch()">&#10005; Close results</div><div class="lib-ph-s">'+j.total+(j.capped?'+':'')+' matches</div>'+j.items.map(`,
'search-close');

// 3) intelligence ranking: prepend a Close chip
one(`box.innerHTML='<div class="lib-ph-s">Best IPTVs for '+esc(c)+'</div>'+rows.map(`,
`box.innerHTML='<div class="lib-clear" onclick="clearIntel()">&#10005; Close</div><div class="lib-ph-s">Best IPTVs for '+esc(c)+'</div>'+rows.map(`,
'intel-close');

// 4) clearSearch + clearIntel functions
one(`  (function(){ var sel=document.getElementById('intelCountry');`,
`  function clearSearch(){ var q=document.getElementById('srchQ'); if(q) q.value=''; var b=document.getElementById('srchResults'); if(b) b.innerHTML=''; }
  function clearIntel(){ var c=document.getElementById('intelCountry'); if(c) c.value=''; var b=document.getElementById('intelRank'); if(b) b.innerHTML=''; }
  (function(){ var sel=document.getElementById('intelCountry');`,
'fns');

fs.writeFileSync(V, s);
process.exit(0);
PJS
node .pj.js
node -e "var ejs=require('/opt/gsz/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('views/admin/iptv.ejs','utf8'),{filename:'/opt/gsz/views/admin/iptv.ejs'});console.log('  ejs ok');"
rm -f .pj.js
echo "   checks passed"
trap - ERR

echo "==> restart site + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "$V.xbak.$TS" "$V"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
echo "DONE — Close buttons added to search + intelligence."
