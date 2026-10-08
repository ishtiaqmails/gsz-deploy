#!/usr/bin/env bash
GSZ=/opt/gsz; cd "$GSZ"
echo "### lib/mailer.js ###"; cat -n lib/mailer.js
echo "### lib/emails.js ###"; cat -n lib/emails.js
echo "### routes/adminMessages.js ###"; cat -n routes/adminMessages.js
echo "### views/admin/messages.ejs ###"; cat -n views/admin/messages.ejs
echo "### DB: customers schema + counts ###"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{const q=async(l,s)=>{try{const r=await p.query(s);console.log('--- '+l+' ---');console.log(JSON.stringify(r.rows,null,1));}catch(e){console.log(l+' ERR '+e.message);}};await q('customers columns','select column_name,data_type from information_schema.columns where table_name=CHRcustomersCHR order by ordinal_position'.replace(/CHR/g,String.fromCharCode(39)));await q('customer counts','select count(*)::int total, count(email)::int with_email from customers');await q('sample','select id,name,email,created_at from customers order by id desc limit 3');await p.end();})();"
