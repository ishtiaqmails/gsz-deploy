#!/usr/bin/env bash
# dumpP2 — the pieces dumpP missed: botapi.js full, checkout.js head (1-475), correct player DB
GSZ=/opt/gsz; cd "$GSZ"
echo "### lib/botapi.js ###"; cat -n lib/botapi.js
echo
echo "### routes/checkout.js (lines 1-475) ###"; sed -n '1,475p' routes/checkout.js | cat -n
echo
echo "### DB: player products (via bot_sku) + their plans ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});const Q=String.fromCharCode(39);(async()=>{const q=async(l,s,a)=>{try{const r=await p.query(s,a||[]);console.log('--- '+l+' ---');console.log(JSON.stringify(r.rows,null,1));}catch(e){console.log(l+' ERR '+e.message);}};const SKUS=['SKU-00141','SKU-00119','SKU-00144'];await q('products with a player plan','select distinct pr.id,pr.name,pr.slug from products pr join product_plans pp on pp.product_id=pr.id where pp.bot_sku=ANY(\$1)',[SKUS]);await q('player product_plans','select pp.id,pp.product_id,pp.label,pp.price_pkr,pp.old_pkr,pp.sort,pp.source,pp.bot_sku,pp.bot_plan_key,pp.bot_type,pp.warranty from product_plans pp where pp.bot_sku=ANY(\$1) order by pp.product_id,pp.sort',[SKUS]);await q('bot_products player row (full)','select sku,name,delivery_type,needs,plans,types,retrieve,warranty_days,delivery_note from bot_products where sku=ANY(\$1)',[SKUS]);await p.end();})();"
echo
echo "### botapi exports + live player plans ###"
NODE_PATH="$GSZ/node_modules" node -e "const b=require('$GSZ/lib/botapi.js');console.log('exports:',Object.keys(b).join(', '));(async()=>{const names=['products','getProducts','listProducts','allProducts','catalog','fetchProducts'];let fn=null,used=null;for(const n of names){if(typeof b[n]==='function'){fn=b[n];used=n;break;}}if(!fn){console.log('no products-fetch export found');return;}console.log('using export:',used);try{const r=await fn();const a=(r&&r.products)||(Array.isArray(r)?r:[]);a.filter(x=>['SKU-00141','SKU-00119','SKU-00144'].includes(x.sku||x.id)).forEach(x=>{console.log(x.sku||x.id,'|',x.name,'| plans:',JSON.stringify(x.plans||x.durations||x.options||[]));});}catch(e){console.log('call ERR',e.message);}})();"
