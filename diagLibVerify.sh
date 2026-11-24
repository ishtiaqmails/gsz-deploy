#!/usr/bin/env bash
# READ-ONLY. Verify each zayron server maps to the CORRECT galaxyzayron library entry + show admin edit count fields.
Z=/opt/zayron; cd "$Z"
echo "### mapping: zayron server -> matched galaxyzayron entry + counts ###"
node -e '
const fs=require("fs"); const {Pool}=require("/opt/zayron/node_modules/pg"); const {pool}=require("./db");
const env={}; try{ fs.readFileSync("/opt/gsz/.env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/i); if(m) env[m[1]]=m[2].replace(/^["\x27]|["\x27]$/g,"").trim();}); }catch(e){}
const gp=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS,database:env.DB_NAME,max:2});
const norm=s=>String(s||"").toLowerCase().replace(/[^a-z0-9]/g,"").replace(/iptv|ott|tv/g,"");
(async()=>{
  const lib=(await gp.query("SELECT server_key,name,live_count,vod_count,series_count FROM iptv_library")).rows.map(x=>({key:x.server_key,name:x.name,nk:norm(x.name),ns:norm(x.server_key),live:+x.live_count,vod:+x.vod_count,series:+x.series_count}));
  const sv=(await pool.query("SELECT slug,name FROM servers WHERE active=true ORDER BY id")).rows;
  for(const s of sv){
    const ns=norm(s.slug), nn=norm(s.name);
    let hit=lib.find(x=>(ns&&x.ns===ns)||(nn&&x.nk===nn));
    if(!hit) hit=lib.find(x=>(x.nk&&nn&&(x.nk.indexOf(nn)===0||nn.indexOf(x.nk)===0))||(x.ns&&ns&&(x.ns.indexOf(ns)===0||ns.indexOf(x.ns)===0)));
    console.log(("["+s.slug+"] "+s.name).padEnd(42), "=>", hit?("GSZ:"+hit.name+"  "+hit.live+"/"+hit.vod+"/"+hit.series):"NO MATCH");
  }
  process.exit(0);
})().catch(e=>{console.log("ERR",e.message);process.exit(0)});
'
echo
echo "### admin edit: the card-count fields to remove (512-520) ###"
sed -n '512,520p' routes/admin.js
echo DONE
