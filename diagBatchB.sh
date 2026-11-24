#!/usr/bin/env bash
# READ-ONLY. Find galaxyzayron's DB module, list its iptv_library server_keys + products slug<->sku to map by bot_sku.
G=/opt/gsz
echo "### how gsz connects to its DB ###"
grep -rnE "new Pool|require\(.*db|DATABASE_URL|PGDATABASE|pool =" "$G/server.js" "$G/db"* 2>/dev/null | head -8
ls "$G/db" 2>/dev/null; echo "db.js?"; ls "$G"/db.js 2>/dev/null
echo
echo "### gsz iptv_library server_keys + counts (via gsz app over http is public summary; here list keys) ###"
# use gsz's own node context to query
node -e "process.chdir('$G'); let pool; try{ pool=require('$G/db').pool||require('$G/db'); }catch(e){ try{ pool=require('$G/db/index').pool; }catch(e2){ console.log('db load fail:',e.message); process.exit(0);} } pool.query('SELECT server_key,name,live_count,vod_count,series_count FROM iptv_library ORDER BY server_key').then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e=>{console.log('q err',e.message);process.exit(0)})" 2>/dev/null
echo
echo "### gsz products slug <-> sku <-> name ###"
node -e "process.chdir('$G'); let pool; try{ pool=require('$G/db').pool||require('$G/db'); }catch(e){ try{ pool=require('$G/db/index').pool; }catch(e2){ process.exit(0);} } pool.query(\"SELECT slug,sku,name FROM products WHERE sku IS NOT NULL ORDER BY slug\").then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e=>{pool.query('SELECT slug,name FROM products ORDER BY slug').then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e2=>{console.log('q2 err',e2.message);process.exit(0)})})" 2>/dev/null
echo DONE
