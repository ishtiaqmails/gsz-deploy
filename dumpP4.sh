#!/usr/bin/env bash
# dumpP4 — how product plans are managed in admin (to add per-duration player plans cleanly)
GSZ=/opt/gsz; cd "$GSZ"
echo "### admin route files ###"; ls -1 routes | grep -i -E 'admin|mapping|catalog'
echo
echo "### where product_plans / bot_plan_key are touched (routes) ###"
grep -rn "product_plans\|bot_plan_key\|bot_sku" routes/admin*.js routes/adminMapping.js routes/adminCatalog.js 2>/dev/null | head -80
echo
echo "### views that mention plans / mapping ###"; ls -1 views/admin 2>/dev/null
echo
echo "### grep plan editor UI in admin views ###"
grep -rln "bot_plan_key\|product_plans\|plan_key\|Plans\|plans\[" views/admin 2>/dev/null
echo
echo "### DB: full plan+product for the two players ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{const q=async(l,s,a)=>{try{const r=await p.query(s,a||[]);console.log('--- '+l+' ---');console.log(JSON.stringify(r.rows,null,1));}catch(e){console.log(l+' ERR '+e.message);}};await q('products 53/54','select id,name,slug,category_id from products where id in (53,54)');await q('their plans','select * from product_plans where product_id in (53,54) order by product_id,sort,id');await q('product_plans columns','select column_name,data_type from information_schema.columns where table_name=CHRproduct_plansCHR order by ordinal_position'.replace(/CHR/g,String.fromCharCode(39)));await p.end();})();"
