GSZ=/opt/gsz; cd $GSZ
echo "===== A) SELF-UPDATE / STALENESS ====="
grep -nE "REFRESH_HOURS|SWEEP_MS|cutoff|staleServers" lib/iptv/worker.js
L=$(grep -n "staleServers" lib/iptv/worker.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "$((L-1)),$((L+22))p" lib/iptv/worker.js
echo "-- routes/iptv.js servers endpoint --"
L=$(grep -n "iptv/servers" routes/iptv.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "$((L-1)),$((L+30))p" routes/iptv.js
echo "-- setting store --"
grep -rnE "wa_settings|getSetting|setSetting|get_setting" lib/*.js routes/iptv.js routes/adminIptv.js | head -20
echo "===== B) PRODUCT PAGE ====="
grep -rn "render('product'" routes/*.js server.js | head
echo "-- product.ejs anchors --"
grep -nE "whats|inside|library|What|Channels|VOD|Movies|Series|plans|price|summary.json|server_key|iptv|category" views/product.ejs | head -70
PR=$(grep -rln "render('product'" routes/*.js server.js | head -1); echo "route file: $PR"
[ -n "$PR" ] && grep -nE "iptv_library|summary|server_key|live_count|vod_count|series_count|categories|slug" "$PR" | head -20
echo "===== C) INTEL FUNCTIONS ====="
grep -nE "function intel|function classify|categories|country|language" routes/adminIptv.js | head -25
echo "-- iptv_library columns --"
node -e "const{Pool}=require('pg');const p=new Pool();p.query(\"select column_name from information_schema.columns where table_name='iptv_library' order by ordinal_position\").then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));p.end()}).catch(e=>{console.log('ERR',e.message);p.end()})"
node -e "const{Pool}=require('pg');const p=new Pool();p.query(\"select server_key, live_count, vod_count, series_count, left(categories::text,400) cat from iptv_library order by updated_at desc limit 3\").then(r=>{r.rows.forEach(x=>console.log(x.server_key,'L'+x.live_count,'V'+x.vod_count,'S'+x.series_count,x.cat));p.end()}).catch(e=>{console.log('ERR',e.message);p.end()})"
echo DONE
