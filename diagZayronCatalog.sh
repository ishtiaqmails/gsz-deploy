#!/usr/bin/env bash
# diagZayronCatalog — how zayron.tv pulls products from the reseller bot, the catalog/mapping model, and WHERE the
# IPTV-only filter lives (so we can show ALL mapped product types). READ-ONLY.
set +e
cd /opt/zayron 2>/dev/null || { echo "no /opt/zayron"; exit 0; }
echo "########## reseller-bot bridge: lib/gszApi.js getProducts (what it returns + any type filter) ##########"
ls lib/gszApi.js 2>/dev/null && grep -n "getProducts\|delivery_type\|iptv\|type\|filter\|category\|module.exports\|cache\|TTL" lib/gszApi.js | head -30
echo
echo "########## planSync.js: how servers/plans sync from bot products (IPTV filter?) ##########"
ls lib/planSync.js 2>/dev/null && grep -n "iptv\|delivery_type\|type\|filter\|INSERT\|servers\|bot_sku\|getProducts\|where\|WHERE" lib/planSync.js | head -30
echo
echo "########## where 'iptv' / delivery_type is filtered across zayron (lib + routes) ##########"
grep -rn "delivery_type\|'iptv'\|\"iptv\"\|=='iptv'\|delivery_type.*iptv\|type.*=.*iptv" lib routes 2>/dev/null | grep -v node_modules | grep -v "\.bak" | head -30
echo
echo "########## zayron catalog tables (servers / products / plans / mapping) ##########"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();(async()=>{try{
const t=await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%server%' OR table_name ILIKE '%product%' OR table_name ILIKE '%plan%' OR table_name ILIKE '%bot%' OR table_name ILIKE '%map%') ORDER BY table_name\");
console.log('tables:', t.rows.map(x=>x.table_name).join(', '));
for(const tn of ['servers','server_plans','products','product_plans','bot_products']){ try{ const c=await p.query('SELECT column_name FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position',[tn]); if(c.rows.length) console.log('  '+tn+': '+c.rows.map(x=>x.column_name).join(', ')); }catch(e){} }
// how many servers, and do any carry a non-iptv type?
try{ const s=await p.query(\"SELECT count(*)::int n FROM servers\"); console.log('servers count:', s.rows[0].n); }catch(e){}
}catch(e){console.log('ERR',e.message);}await p.end();})();" 2>&1 | tail -15
echo
echo "########## the storefront product-list query (what customers see) ##########"
grep -rn "FROM servers\|FROM products\|loadProducts\|loadServers\|SELECT.*servers\|ORDER BY sort" lib routes server.js 2>/dev/null | grep -v node_modules | grep -v "\.bak" | head -15
echo DONE
