#!/usr/bin/env bash
# Read-only: GSZ Netflix readiness — portal reachability, key, nf_* tables, Netflix products.
GSZ=/opt/gsz; cd "$GSZ"
echo "===== NF_READ_KEY in /opt/gsz/.env? ====="
grep -q '^NF_READ_KEY=' .env && echo "NF_READ_KEY: present" || echo "NF_READ_KEY: MISSING"
echo
echo "===== Netflix Portal reachable from this box (127.0.0.1:3100)? ====="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:3100/internal/account-emails?email=test@test.com" || echo "no-connect")
echo "portal /internal/account-emails (no key) -> $code   (403 = up & guarded, good; 000/no-connect = not reachable)"
echo
echo "===== GSZ Netflix code (nfMail/netflixGate + hub) ====="
ls lib/nfMail.js lib/netflixGate.js 2>/dev/null || echo "(no nfMail.js / netflixGate.js yet)"
grep -rilE "nf_account|nf_assign|netflix|code_source" routes/*.js lib/*.js views/partials/hub_model.ejs 2>/dev/null | head
echo
echo "===== DB: nf_* tables + Netflix products ====="
node -e "const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});const{Pool}=require(R+'/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{const t=(await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'nf_%'\")).rows.map(r=>r.table_name);console.log('nf_ tables:',t.length?t.join(', '):'(none)');const nf=(await p.query(\"SELECT slug,name FROM products WHERE active AND NOT hidden AND (lower(name) LIKE '%netflix%') ORDER BY name\").catch(()=>({rows:[]}))).rows;console.log('Netflix products ('+nf.length+'):',nf.slice(0,8).map(r=>r.slug).join(', '));await p.end();})().catch(e=>console.log('db:',e.message));"
