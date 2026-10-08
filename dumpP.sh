#!/usr/bin/env bash
# dumpP — current live source for the player activation build
GSZ=/opt/gsz; cd "$GSZ"
echo "### lib/botapi.js ###"; cat -n lib/botapi.js
echo
echo "### routes/checkout.js ###"; cat -n routes/checkout.js
echo
echo "### views/product.ejs ###"; cat -n views/product.ejs
echo
echo "### DB: player bot_products + their product_plans ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});const Q=String.fromCharCode(39);(async()=>{const q=async(l,s)=>{try{const r=await p.query(s);console.log('--- '+l+' ---');console.log(JSON.stringify(r.rows,null,1));}catch(e){console.log(l+' ERR '+e.message);}};await q('player bot_products','select sku,name,delivery_type,price_pkr,plans,types,warranty_days from bot_products where sku in (CHRSKU-00141CHR,CHRSKU-00119CHR,CHRSKU-00144CHR)'.replace(/CHR/g,Q));await q('player products','select id,name,category_id,delivery_type,bot_sku from products where delivery_type in (CHRhotplayerCHR,CHRibosolCHR,CHRzayronCHR)'.replace(/CHR/g,Q));await q('their product_plans','select pp.id,pp.product_id,pp.label,pp.price_pkr,pp.old_pkr,pp.sort,pp.source,pp.bot_sku,pp.bot_plan_key,pp.bot_type,pp.warranty from product_plans pp join products pr on pr.id=pp.product_id where pr.delivery_type in (CHRhotplayerCHR,CHRibosolCHR,CHRzayronCHR) order by pp.product_id,pp.sort'.replace(/CHR/g,Q));await p.end();})();"
echo
echo "### live bot /api/products player plans (sku + plans only) ###"
NODE_PATH="$GSZ/node_modules" node -e "const b=require('$GSZ/lib/botapi.js');(async()=>{try{const r=await b.products();const a=(r&&r.products)||r||[];a.filter(x=>['SKU-00141','SKU-00119','SKU-00144'].includes(x.sku||x.id)).forEach(x=>{console.log(x.sku||x.id,'|',x.name,'| delivery:',x.delivery_type||x.type,'| plans:',JSON.stringify(x.plans||x.durations||[]));});}catch(e){console.log('bot products ERR',e.message);}})();"
