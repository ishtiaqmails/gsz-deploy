#!/usr/bin/env bash
# READ-ONLY. Connect to gsz DB via its .env and list iptv_library keys + products slug/sku.
echo "### gsz Pool config (server.js 10-28) ###"
sed -n '10,28p' /opt/gsz/server.js
echo
echo "### gsz .env DB keys present (names only) ###"
grep -oE "^(DB_[A-Z]+|PG[A-Z]+|DATABASE_URL)" /opt/gsz/.env 2>/dev/null
echo
echo "### query gsz DB (iptv_library + products) ###"
node -e "
const fs=require('fs'); const {Pool}=require('/opt/zayron/node_modules/pg');
const env={}; try{ fs.readFileSync('/opt/gsz/.env','utf8').split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)\$/i); if(m) env[m[1]]=m[2].replace(/^[\"']|[\"']\$/g,'').trim();}); }catch(e){}
const cfg = env.DATABASE_URL ? { connectionString: env.DATABASE_URL } : { host: env.DB_HOST||env.PGHOST||'127.0.0.1', port:+(env.DB_PORT||env.PGPORT||5432), user: env.DB_USER||env.PGUSER, password: env.DB_PASSWORD||env.PGPASSWORD, database: env.DB_NAME||env.PGDATABASE };
const pool=new Pool(cfg);
(async()=>{
  try{ const r=await pool.query('SELECT server_key,name,live_count,vod_count,series_count FROM iptv_library ORDER BY server_key'); console.log('--- iptv_library ('+r.rows.length+') ---'); r.rows.forEach(x=>console.log(JSON.stringify(x))); }catch(e){ console.log('lib err:',e.message); }
  try{ const p=await pool.query(\"SELECT slug,sku,name FROM products WHERE delivery_type='iptv' ORDER BY slug\"); console.log('--- products ('+p.rows.length+') ---'); p.rows.forEach(x=>console.log(JSON.stringify(x))); }catch(e){ console.log('prod err:',e.message); }
  process.exit(0);
})();
"
echo DONE
