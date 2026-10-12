#!/usr/bin/env bash
# hero/banner diagnostic — read-only. Find the hero markup + how its images load.
GSZ=/opt/gsz; cd "$GSZ"
echo "### locate hero/banner markup in views ###"
grep -rln "hero\|banner\|slide\|promo" views 2>/dev/null | head
echo
echo "### hero/banner markup + image loading (first matching view) ###"
HF=$(grep -rln "class=\"hero\|id=\"hero\|hero-\|bannerWrap\|heroSlide\|banner-\|promoSlide\|slides" views 2>/dev/null | head -1)
echo "hero file: ${HF:-<none found>}"
[ -n "$HF" ] && grep -n "hero\|banner\|slide\|<img\|data-src\|loading=\|fetchpriority\|background-image\|style=" "$HF" | head -50
echo
echo "### how banners are sourced (api/server) ###"
grep -rn "banners\|/api/banners\|heroBanners\|loadBanners\|slides" routes lib views 2>/dev/null | head -20
echo
echo "### app.css: offer + hero/banner rules ###"
grep -n "\.offer\|hero\|banner\|\.slide" public/css/app.css 2>/dev/null | head -40
echo
echo "### DB: a banners/hero table? + sample ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const t=await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_name ~ 'banner|hero|slide|promo'\");console.log('tables:',JSON.stringify(t.rows));for(const r of t.rows){try{const s=await p.query('SELECT * FROM '+r.table_name+' LIMIT 3');console.log('--- '+r.table_name+' ('+s.rowCount+') cols:',Object.keys(s.rows[0]||{}).join(','));console.log(JSON.stringify(s.rows,null,1).slice(0,1200));}catch(e){console.log(r.table_name,'ERR',e.message);}}}catch(e){console.log('ERR',e.message);}await p.end();})();"
