#!/usr/bin/env bash
# Polish: status text only red on real failures; clear the harmless migration note.
cd /opt/gsz
f=/opt/gsz/views/admin/email.ejs
bak="$f.bak.$(date +%s)"
cp "$f" "$bak"
node <<'EOF'
const fs=require('fs');
const f='/opt/gsz/views/admin/email.ejs';
const orig=fs.readFileSync(f,'utf8');
const a='<% if (r.last_status) { %><div class="status <%= /^ok/i.test(r.last_status)?\'ok\':\'bad\' %>">Last check: <%= r.last_status %></div><% } %>';
const b='<% if (r.last_status) { var _sb=/(fail|error|timeout|http_|unconfigured|invalid|denied|unauthor)/i.test(r.last_status); var _sc=(/^ok/i.test(r.last_status)?\'ok\':(_sb?\'bad\':\'\')); %><div class="status <%= _sc %>">Last check: <%= r.last_status %></div><% } %>';
const n=orig.split(a).length-1;
if(n!==1){ console.log('FAIL anchor count='+n); process.exit(1); }
const s=orig.split(a).join(b);
try{ require('/opt/gsz/node_modules/ejs').compile(s); }catch(e){ console.log('FAIL ejs '+e.message); process.exit(1); }
fs.writeFileSync(f,s);
console.log('OK view patched');
EOF
if [ $? -ne 0 ]; then echo "reverting view"; cp "$bak" "$f"; fi
node <<'EOF'
require('dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ try{ const r=await pool.query("UPDATE email_providers SET last_status='' WHERE last_status='migrated from current config'"); console.log('cleared migration note on '+r.rowCount+' row(s)'); }catch(e){ console.log('db note: '+e.message); } process.exit(0); })();
EOF
pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"
echo DONE
