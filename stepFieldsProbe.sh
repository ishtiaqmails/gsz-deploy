#!/usr/bin/env bash
# stepFieldsProbe.sh — READ-ONLY. Dump the live `fields` object the bot now returns for recent
# delivered orders, so the website composer is built from the real shape (labels, keys, nesting).
set -u
GSZ=/opt/gsz; cd "$GSZ"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const botapi=require(R+'/lib/botapi');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const rows=(await pool.query(\"SELECT order_no, product_name FROM orders WHERE source='bot' AND status IN ('delivered','completed') ORDER BY id DESC LIMIT 6\")).rows;
  if(!rows.length){ console.log('no delivered bot orders'); await pool.end(); return; }
  for(const o of rows){
    console.log('\\n===== '+o.order_no+'  ('+o.product_name+') =====');
    try{ const r=await botapi.orderStatus(o.order_no); console.log('fields:', r && r.fields ? JSON.stringify(r.fields,null,2) : '(none returned)'); }
    catch(e){ console.log('ERR:', e.message); }
  }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"
