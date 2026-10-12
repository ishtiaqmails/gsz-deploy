#!/usr/bin/env bash
# #82 slug fix — diagnostic. Read-only. Shows the /product/:slug route lookup + live product/plan inventory.
GSZ=/opt/gsz; cd "$GSZ"
echo "### grep: slug / product route / redirect / 404 in routes/products.js ###"
grep -n "slug\|router\.get(\|router\.use(\|res\.redirect\|404\|notFound\|render('product'\|WHERE" routes/products.js | head -60
echo
echo "### routes/products.js lines 1,120 (route head + slug lookup) ###"
sed -n '1,120p' routes/products.js
echo
echo "### DB: product inventory (id,name,slug,active,hidden,plan_count) ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const r=await p.query(\"SELECT pr.id, pr.name, pr.slug, pr.active, pr.hidden, (SELECT count(*)::int FROM product_plans pp WHERE pp.product_id=pr.id) AS plans FROM products pr ORDER BY pr.id\");console.log(JSON.stringify(r.rows,null,1));}catch(e){console.log('ERR '+e.message);}await p.end();})();"
echo
echo "### DB: does cs_redirects / any product redirect table exist? ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const r=await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_name ~ 'redirect|slug|alias'\");console.log(JSON.stringify(r.rows,null,1));const c=await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='products' ORDER BY ordinal_position\");console.log('products cols:', c.rows.map(x=>x.column_name).join(', '));}catch(e){console.log('ERR '+e.message);}await p.end();})();"
