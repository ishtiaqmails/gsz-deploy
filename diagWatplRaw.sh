#!/usr/bin/env bash
# diagWatplRaw — does watpl.compose render a raw body for template_key 'whatsapp.raw'? Dry-run only; sends nothing.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "### lib/watpl.js: compose + any raw/body handling ###"
grep -n "raw\|vars.body\|\.body\|function compose\|module.exports\|whatsapp\.\|default\|switch\|case '" lib/watpl.js | head -40
echo
echo "### DB templates table (if any) keyed near 'raw' ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{const t=await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%templ%'\");console.log('template tables:',t.rows.map(x=>x.table_name).join(', ')||'(none)');for(const tn of t.rows.map(x=>x.table_name)){try{const c=await p.query('SELECT * FROM '+tn+\" WHERE key ILIKE '%raw%' OR key ILIKE '%whatsapp.raw%' LIMIT 5\");console.log(tn,'raw rows:',JSON.stringify(c.rows));}catch(e){console.log(tn,'q err',e.message);}}}catch(e){console.log('ERR',e.message);}await p.end();})();" 2>&1 | tail -8
echo
echo "### DRY-RUN watpl.compose(pool,'whatsapp.raw',{body:'TEST-CODE-123456'}) ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});const watpl=require('./lib/watpl');(async()=>{try{const out=await watpl.compose(p,'whatsapp.raw',{body:'TEST-CODE-123456'});console.log('COMPOSED >>>');console.log(out===undefined?'(undefined)':(out===null?'(null)':out));console.log('<<< END');}catch(e){console.log('COMPOSE ERR',e.message);}await p.end();})();" 2>&1 | tail -12
echo DONE
