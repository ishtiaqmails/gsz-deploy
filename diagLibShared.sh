#!/usr/bin/env bash
# READ-ONLY. Can zayron read galaxyzayron's iptv_library directly (same DB)? + schema + server_key mapping.
echo "### TEST: can ZAYRON query iptv_library directly? (same DB?) ###"
(cd /opt/zayron && node -e "const{pool}=require('./db');pool.query('SELECT count(*)::int n FROM iptv_library').then(r=>{console.log('YES same DB — iptv_library rows:',r.rows[0].n);process.exit(0)}).catch(e=>{console.log('NO / error:',e.message);process.exit(0)})")
echo
echo "### iptv_library schema ###"
(cd /opt/gsz && node -e "const{pool}=require('./db');pool.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='iptv_library' ORDER BY ordinal_position\").then(r=>{r.rows.forEach(x=>console.log(x.column_name,'|',x.data_type));process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})")
echo
echo "### iptv_library sample rows (server_key + counts) ###"
(cd /opt/gsz && node -e "const{pool}=require('./db');pool.query('SELECT server_key,name,live_count,vod_count,series_count,episode_count FROM iptv_library ORDER BY server_key LIMIT 20').then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})")
echo
echo "### how galaxyzayron maps server_key -> product/server (live routes/iptv.js) ###"
grep -nE "server_key|iptv_library|What.s Inside|search|counts|/iptv/" /opt/gsz/routes/iptv.js 2>/dev/null | head -20
echo
echo "### zayron servers: slug / reseller_pid / bot_sku (to match server_key) ###"
(cd /opt/zayron && node -e "const{pool}=require('./db');pool.query('SELECT slug,reseller_pid,bot_sku,name FROM servers ORDER BY id').then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})")
echo DONE
