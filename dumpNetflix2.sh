#!/usr/bin/env bash
# Read-only structural map of the GSZ Netflix system (schemas + key fns + routes + plan data).
GSZ=/opt/gsz; cd "$GSZ"
echo "===== netflixGate.js — tier logic (how a plan -> tier -> allowed codes) ====="
grep -nE "PLAN_ALLOW|tierForPlan|allowedTypesFor|filterEmails|refineType|module.exports|function |tier" lib/netflixGate.js 2>/dev/null | head -30
echo
echo "===== netflixCodes.js — customer route(s) + what they read/render ====="
grep -nE "router\.(get|post)|res.render|res.json|_nf|nf_assign|tier|nfMail|nfGate|listForAccount" routes/netflixCodes.js 2>/dev/null | head -25
echo
echo "===== adminNetflix.js — what the admin manages (routes) ====="
grep -nE "router\.(get|post)|nf_accounts|nf_assignments|INSERT INTO|UPDATE|tier|profile|assign|credentials" routes/adminNetflix.js 2>/dev/null | head -25
echo
echo "===== deliver.js — Netflix fulfillment / auto-assign ====="
grep -nE "nf_account|nf_assign|netflix|code_source|tier|profile|assign|INSERT INTO nf" lib/deliver.js 2>/dev/null | head -20
echo
echo "===== DB schemas + plan data ====="
node -e "const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});const{Pool}=require(R+'/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});const cols=async t=>(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name=\$1 ORDER BY ordinal_position\",[t])).rows.map(r=>r.column_name).join(', ');(async()=>{console.log('nf_accounts:',await cols('nf_accounts'));console.log('nf_assignments:',await cols('nf_assignments'));console.log('product_plans:',await cols('product_plans'));const pl=(await p.query(\"SELECT pp.label, pp.price_pkr FROM product_plans pp JOIN products p2 ON p2.id=pp.product_id WHERE p2.slug='netflix-premium' ORDER BY pp.sort,pp.id\").catch(()=>({rows:[]}))).rows;console.log('netflix-premium plans:',JSON.stringify(pl));console.log('nf_accounts rows:',(await p.query('SELECT count(*) n FROM nf_accounts').catch(()=>({rows:[{n:'?'}]}))).rows[0].n,'| nf_assignments rows:',(await p.query('SELECT count(*) n FROM nf_assignments').catch(()=>({rows:[{n:'?'}]}))).rows[0].n);await p.end();})().catch(e=>console.log('db:',e.message));"
