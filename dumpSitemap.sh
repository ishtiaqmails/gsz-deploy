#!/usr/bin/env bash
# dumpSitemap.sh — READ ONLY. The live sitemap builder (to add geo + pick pages) and how many
# indexable geo pages exist (to decide single sitemap vs sitemap index).
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
echo "===== routes/sitemap.js (full) ====="
cat -n routes/sitemap.js
echo
echo "===== counts: what the sitemap should cover ====="
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const q=async(s,p)=>{try{return (await pool.query(s,p)).rows[0].n;}catch(e){return 'ERR:'+e.message;}};
  console.log('  products active   :', await q("SELECT count(*)::int n FROM products WHERE active AND NOT hidden"));
  console.log('  categories active :', await q("SELECT count(*)::int n FROM categories WHERE active"));
  console.log('  cs_posts published:', await q("SELECT count(*)::int n FROM cs_posts WHERE status='published'"));
  console.log('  geo PUBLISHED     :', await q("SELECT count(*)::int n FROM geo_pages WHERE status='PUBLISHED'"));
  console.log('  geo INDEX (live)  :', await q("SELECT count(*)::int n FROM geo_pages WHERE status='PUBLISHED' AND indexing_status='INDEX'"));
  console.log('  geo by type (INDEX):');
  try{ const r=await pool.query("SELECT page_type, count(*)::int n FROM geo_pages WHERE status='PUBLISHED' AND indexing_status='INDEX' GROUP BY page_type ORDER BY n DESC"); r.rows.forEach(x=>console.log('     '+x.page_type+': '+x.n)); }catch(e){console.log('   '+e.message);}
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE
