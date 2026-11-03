GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "===== STORED COUNTS: clean vs raw, per panel ====="
node -e "require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});const{Pool}=require('/opt/gsz/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT server_key,live_count,vod_count,series_count,episode_count,raw_live,raw_vod,raw_series,adult_hidden,last_via,to_char(updated_at,'MM-DD HH24:MI') u FROM iptv_library ORDER BY (COALESCE(raw_vod,0)+COALESCE(raw_live,0)) DESC\").then(r=>{console.log('key | live(raw) | vod(raw) | series(raw) | eps | adult | via | upd');r.rows.forEach(x=>console.log(x.server_key+' | '+x.live_count+'('+x.raw_live+') | '+x.vod_count+'('+x.raw_vod+') | '+x.series_count+'('+x.raw_series+') | '+x.episode_count+' | '+x.adult_hidden+' | '+(x.last_via||'')+' | '+x.u));return p.end();}).catch(e=>{console.log('ERR',e.message);p.end();})"
echo
echo "===== clean.enhance (counts + dedupe) ====="
sed -n '140,200p' lib/iptv/clean.js
echo
echo "===== worker store(): what maps to each count col ====="
sed -n '30,60p' lib/iptv/worker.js
echo
echo "===== m3u parse: caps / counting ====="
grep -n "100000\|\.add(\|plus\|push(\|continue\|slice(\|length\|count\|Set(" lib/iptv/m3u.js | head -40
echo
echo "===== fetch.js player_api: does it get ALL (no pagination)? ====="
sed -n '1,40p' lib/iptv/fetch.js
echo DONE
