#!/usr/bin/env bash
# dumpGeoEngine.sh — READ ONLY, focused. What a curated-page builder must plug into:
#   geo_pages columns, how slugs/pages are generated, and how the view gets its product list.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
echo "===== geo_pages columns ====="
node -e '
const path=require("path");try{require("/opt/gsz/node_modules/dotenv").config({path:"/opt/gsz/.env"});}catch(e){}
const {Pool}=require("/opt/gsz/node_modules/pg");
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{const r=await pool.query("SELECT column_name,data_type,column_default FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",["geo_pages"]);
for(const x of r.rows)console.log("  "+x.column_name.padEnd(22)+x.data_type+(x.column_default?("  def="+String(x.column_default).slice(0,34)):""));
const s=await pool.query("SELECT id,slug,page_type,category_id,country_id,region_id,city_id,status FROM geo_pages ORDER BY id DESC LIMIT 3");
console.log("\n  sample rows:");for(const x of s.rows)console.log("   "+JSON.stringify(x));
await pool.end();})().catch(e=>{console.error(e.message);process.exit(1);});'
echo
echo "===== lib/geo_admin.js : generate() — how a page row is built (slug/page_type/content) ====="
ln=$(grep -nE "generate\s*[:=]|async generate|function generate" lib/geo_admin.js | head -1 | cut -d: -f1); ln=${ln:-1}
sed -n "${ln},$((ln+75))p" lib/geo_admin.js
echo
echo "===== lib/geo_admin.js : where the slug string is composed ====="
grep -nE "slug" lib/geo_admin.js | head -20
echo
echo "===== routes/geo.js : how the rendered product list is chosen (category/loadProducts) ====="
grep -nE "loadProducts|category_id|page_type|content_data|applyGeoRules|collection" routes/geo.js | head -25
