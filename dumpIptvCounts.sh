GSZ=/opt/gsz; cd /opt/gsz
echo "===== iptv_library counts per panel (computed vs raw) ====="
node <<'EOF'
require('dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
 try{
  const r=await pool.query("SELECT server_key,name,live_count,vod_count,series_count,raw_live,raw_vod,raw_series,status,to_char(updated_at,'MM-DD HH24:MI') upd FROM iptv_library ORDER BY name");
  r.rows.forEach(x=>console.log((x.name||x.server_key)+'  | live '+x.live_count+'/raw '+x.raw_live+'  | vod '+x.vod_count+'/raw '+x.raw_vod+'  | series '+x.series_count+'/raw '+x.raw_series+'  | '+x.status+' '+x.upd));
 }catch(e){ console.log('ERR '+e.message); }
 process.exit(0);
})();
EOF
echo
echo "===== worker files + how raw_* is computed ====="
ls -la lib/iptv/ 2>/dev/null
grep -rnE "raw_live|raw_vod|raw_series|\.length|get_live|get_vod|get_series|player_api|panel|pageSize|limit|cap" lib/iptv/worker.js 2>/dev/null | head -45
echo DONE
