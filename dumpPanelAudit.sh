#!/usr/bin/env bash
# dumpPanelAudit.sh — read-only. Audit EVERY IPTV panel's orders for silent provisioning failures:
#   (1) delivered orders with NO bot_order_id (line may never have been created)
#   (2) duplicate delivered credentials across orders (shared/stock instead of fresh lines)
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
node - "$GSZ" <<'NODE' 2>&1 | head -80
const R=process.argv[2]; try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg');const E=process.env;
let pool=E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):((E.DB_HOST||E.DB_NAME)?new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE}):new Pool());
function uname(c){ var m=String(c||'').match(/Username:\s*([^\s]+)/i); return m?m[1]:''; }
(async()=>{ try{
  const iptv=(await pool.query("SELECT sku,name FROM bot_products WHERE delivery_type='iptv' ORDER BY name")).rows;
  console.log('IPTV panels: '+iptv.length);
  for(const p of iptv){
    const os=(await pool.query("SELECT id,order_no,status,bot_order_id,COALESCE(delivered_credentials,'') cred FROM orders WHERE bot_sku=$1 AND status IN ('delivered','delivering') ORDER BY id DESC LIMIT 50",[p.sku])).rows;
    if(!os.length) continue;
    const noBot=os.filter(o=>!o.bot_order_id);
    const byCred={}; os.forEach(o=>{ var u=uname(o.cred); if(u){ (byCred[u]=byCred[u]||[]).push(o.order_no||o.id); }});
    const dups=Object.keys(byCred).filter(u=>byCred[u].length>1);
    const flag=(noBot.length||dups.length)?'  <-- CHECK':'';
    console.log('\n== '+p.name+' ('+p.sku+') — '+os.length+' recent orders'+flag);
    console.log('   with bot_order_id: '+(os.length-noBot.length)+' | without: '+noBot.length);
    if(noBot.length) console.log('   NO bot_order_id: '+noBot.slice(0,8).map(o=>o.order_no||o.id).join(', '));
    if(dups.length){ dups.slice(0,5).forEach(u=>console.log('   DUPLICATE line username '+u+' -> orders '+byCred[u].join(', '))); }
    else console.log('   all credentials unique (fresh lines) ✓');
  }
}catch(e){console.log('db err:',e.message);} try{await pool.end();}catch(e){} })();
NODE
echo "== END =="
