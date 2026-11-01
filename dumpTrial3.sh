#!/usr/bin/env bash
# dumpTrial3.sh — READ ONLY. The latest Mega trial attempt + whether our fix computes plan_key/type
# + what the bot's live /api/products says Mega needs. Confirms if the remaining failure is bot-side.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  console.log('=== last 4 trial_claims ===');
  const r=await pool.query("SELECT id,trial_type,status,server_name,bot_ref,has_creds,claimed_at FROM (SELECT id,trial_type,status,server_name,bot_ref,(credentials IS NOT NULL AND credentials<>'') has_creds,claimed_at FROM trial_claims ORDER BY id DESC LIMIT 4) q ORDER BY id DESC");
  r.rows.forEach(x=>console.log('  '+JSON.stringify(x)));

  console.log('\n=== trialspec.trialExtras for Mega (SKU-00097) — what our fix now sends ===');
  try{ const ts=require('/opt/gsz/lib/trialspec'); const ex=await ts.trialExtras(pool,'SKU-00097'); console.log('  '+JSON.stringify(ex)); }catch(e){ console.log('  ERR '+e.message); }

  console.log('\n=== bot live /api/products — Mega entry (needs/trial/plans/types) ===');
  try{
    const botapi=require('/opt/gsz/lib/botapi');
    const prods=await botapi.getProducts(true);
    const list=Array.isArray(prods)?prods:(prods&&prods.products)||[];
    const mega=list.find(p=>p&&(/mega/i.test(p.name||'')||String(p.sku||p.id)==='SKU-00097'||p.id===97));
    console.log('  '+(mega?JSON.stringify({sku:mega.sku,id:mega.id,name:mega.name,delivery_type:mega.delivery_type,trial:mega.trial,needs:mega.needs,plans:mega.plans,types:mega.types}):'(Mega not found in bot products)'));
  }catch(e){ console.log('  bot unreachable: '+e.message); }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE
