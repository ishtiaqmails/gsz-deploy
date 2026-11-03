#!/usr/bin/env bash
# Show RAW library totals (match the real IPTV / player) instead of de-duplicated counts.
# Display-only change. Data already stored in raw_live/raw_vod/raw_series. No re-pull.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
for f in routes/iptv.js views/product.ejs; do cp "$f" "$f.bak.$ts"; done
restore(){ echo "ROLLING BACK"; for f in routes/iptv.js views/product.ejs; do cp "$f.bak.$ts" "$f"; done; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,70))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

// summary.json: return the raw_* columns too
P('routes/iptv.js',[[
`live_count, vod_count, series_count, episode_count, categories, adult_hidden, updated_at`,
`live_count, vod_count, series_count, episode_count, raw_live, raw_vod, raw_series, categories, adult_hidden, updated_at`
]]);

// product.ejs: strip counts + What's-Inside tiles use raw (fallback to clean)
P('views/product.ejs',[
[`document.getElementById('iqLive').textContent=fmt(s.live_count);`,
 `document.getElementById('iqLive').textContent=fmt((+s.raw_live>0?s.raw_live:s.live_count));`],
[`document.getElementById('iqVod').textContent=fmt(s.vod_count);`,
 `document.getElementById('iqVod').textContent=fmt((+s.raw_vod>0?s.raw_vod:s.vod_count));`],
[`document.getElementById('iqSeries').textContent=fmt(s.series_count);`,
 `document.getElementById('iqSeries').textContent=fmt((+s.raw_series>0?s.raw_series:s.series_count));`],
[`'<b>'+fmt(s.live_count)+'</b><span>Live TV</span></div>'`,
 `'<b>'+fmt((+s.raw_live>0?s.raw_live:s.live_count))+'</b><span>Live TV</span></div>'`],
[`'<b>'+fmt(s.vod_count)+'</b><span>Movies</span></div>'`,
 `'<b>'+fmt((+s.raw_vod>0?s.raw_vod:s.vod_count))+'</b><span>Movies</span></div>'`],
[`'<b>'+fmt(s.series_count)+'</b><span>Series</span></div>'`,
 `'<b>'+fmt((+s.raw_series>0?s.raw_series:s.series_count))+'</b><span>Series</span></div>'`]
]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== JS + EJS syntax =="
node -c routes/iptv.js && echo "JS OK" || { restore; exit 1; }
node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');try{ejs.compile(fs.readFileSync('views/product.ejs','utf8'),{filename:'views/product.ejs',includer:()=>({template:''})});console.log('EJS OK');}catch(e){console.log('EJS FAIL',e.message);process.exit(2);}" || { restore; exit 1; }

echo "== restart =="
pm2 restart gsz --update-env
sleep 2
pm2 list | grep -iE "gsz "
echo DONE
