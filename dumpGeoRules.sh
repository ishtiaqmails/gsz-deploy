#!/usr/bin/env bash
# dumpGeoRules.sh — READ ONLY. Shows the schema the product-targeting admin will write to:
# geo_product_rules columns + a few rows, plus the products & categories columns and counts.
set -uo pipefail
GSZ=/opt/gsz
cd "$GSZ"
node <<'NODE'
const path=require('path');
try{require(path.join('/opt/gsz','node_modules','dotenv')).config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  async function cols(t){ const r=await pool.query("SELECT column_name,data_type,is_nullable,column_default FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",[t]); return r.rows; }
  async function cnt(t){ try{const r=await pool.query('SELECT count(*)::int n FROM '+t); return r.rows[0].n;}catch(e){return 'N/A';} }
  for (const t of ['geo_product_rules','products','categories','geo_locations']) {
    const c=await cols(t);
    console.log('\n==== '+t+'  ('+(await cnt(t))+' rows) ====');
    if(!c.length){ console.log('  (table not found)'); continue; }
    for(const x of c) console.log('  '+x.column_name.padEnd(22)+x.data_type+(x.column_default?('  def='+String(x.column_default).slice(0,40)):''));
  }
  console.log('\n==== geo_product_rules sample (up to 8) ====');
  try{ const r=await pool.query('SELECT * FROM geo_product_rules ORDER BY 1 LIMIT 8'); console.log(JSON.stringify(r.rows,null,1)); }catch(e){ console.log('  '+e.message); }
  console.log('\n==== products sample (id,name,price cols) up to 6 ====');
  try{ const r=await pool.query("SELECT * FROM products ORDER BY 1 LIMIT 6"); console.log(JSON.stringify(r.rows.map(x=>({id:x.id,name:x.name||x.title,slug:x.slug,category_id:x.category_id,price:x.price_pkr||x.price||x.from,usd:x.price_usd||x.from_usd,active:x.active||x.is_active})),null,1)); }catch(e){ console.log('  '+e.message); }
  console.log('\n==== geo_locations kinds ====');
  try{ const r=await pool.query("SELECT kind,count(*)::int n FROM geo_locations GROUP BY kind ORDER BY n DESC"); console.log(JSON.stringify(r.rows)); }catch(e){ try{const r2=await pool.query("SELECT type,count(*)::int n FROM geo_locations GROUP BY type ORDER BY n DESC"); console.log('(type) '+JSON.stringify(r2.rows));}catch(e2){console.log('  '+e.message);} }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE
