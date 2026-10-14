#!/usr/bin/env bash
# stepBotRespProbe.sh — READ-ONLY. Dump the RAW bot API response for a delivered GSZ order,
# to see whether the bot already returns STRUCTURED fields (then no bot change needed) or only
# the finished text blob (then the bot API must add a fields object — additive, not its delivery).
set -u
GSZ=/opt/gsz; cd "$GSZ"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const botapi=require(R+'/lib/botapi');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  console.log('bot configured:', botapi.configured());
  const rows=(await pool.query(\"SELECT order_no FROM orders WHERE source='bot' AND status IN ('delivered','completed') ORDER BY id DESC LIMIT 3\")).rows;
  if(!rows.length){ console.log('no delivered bot orders found'); await pool.end(); return; }
  for(const o of rows){
    console.log('\\n===== order-status('+o.order_no+') RAW =====');
    try{ const r=await botapi.orderStatus(o.order_no); console.log(JSON.stringify(r,null,2).slice(0,1600)); }
    catch(e){ console.log('ERR:', e.message, e.body?JSON.stringify(e.body).slice(0,400):''); }
  }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"
