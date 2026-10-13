#!/usr/bin/env bash
# Audit stale product-page fields — read-only. warranty (product + per-plan), notes, geo, offer labels.
GSZ=/opt/gsz; cd "$GSZ"
echo "### how product.ejs renders warranty / notes / rating / sold ###"
grep -n "warranty\|warr\|geo_note\|\.note\b\|offer_label\|Trustpilot\|orders_count\|rating\|version_labels\|avail_note\|product_note" views/product.ejs 2>/dev/null | head -40
echo
echo "### DB: per-product warranty + note + geo_note + offer_label ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const r=(await p.query(\"SELECT id,name,warranty,note,geo_note,offer_label FROM products WHERE active AND NOT hidden ORDER BY id\")).rows;for(const x of r){const bits=[];if(x.warranty)bits.push('warr=\\\"'+x.warranty+'\\\"');if(x.note)bits.push('note=\\\"'+String(x.note).slice(0,50)+'\\\"');if(x.geo_note)bits.push('geo=\\\"'+x.geo_note+'\\\"');if(x.offer_label)bits.push('offer=\\\"'+x.offer_label+'\\\"');if(bits.length)console.log(x.id+' '+x.name+': '+bits.join(' | '));}}catch(e){console.log('ERR',e.message)}await p.end();})();"
echo
echo "### DB: distinct per-PLAN warranty values (how many plans carry old warranty text) ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const r=(await p.query(\"SELECT warranty, count(*)::int n FROM product_plans WHERE warranty IS NOT NULL AND warranty<>'' GROUP BY warranty ORDER BY n DESC\")).rows;console.log(JSON.stringify(r,null,1));}catch(e){console.log('ERR',e.message)}await p.end();})();"
