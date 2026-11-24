#!/usr/bin/env bash
# READ-ONLY. gsz DB via .env (DB_PASS) -> iptv_library keys + products slug/sku.
node -e '
const fs=require("fs"); const {Pool}=require("/opt/zayron/node_modules/pg");
const env={}; try{ fs.readFileSync("/opt/gsz/.env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/i); if(m) env[m[1]]=m[2].replace(/^["\x27]|["\x27]$/g,"").trim();}); }catch(e){}
const pool=new Pool({ host: env.DB_HOST||"127.0.0.1", port:+(env.DB_PORT||5432), user: env.DB_USER, password: env.DB_PASS, database: env.DB_NAME, max:2 });
(async()=>{
  try{ const r=await pool.query("SELECT server_key,name,live_count,vod_count,series_count FROM iptv_library ORDER BY server_key"); console.log("--- iptv_library ("+r.rows.length+") ---"); r.rows.forEach(x=>console.log(JSON.stringify(x))); }catch(e){ console.log("lib err:",e.message); }
  try{ const p=await pool.query("SELECT slug,sku,name FROM products WHERE delivery_type=$1 ORDER BY slug",["iptv"]); console.log("--- products ("+p.rows.length+") ---"); p.rows.forEach(x=>console.log(JSON.stringify(x))); }catch(e){ console.log("prod err:",e.message); }
  process.exit(0);
})();
'
echo DONE
