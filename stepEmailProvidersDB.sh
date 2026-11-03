#!/usr/bin/env bash
# Email providers: create table + migrate current Brevo env config as the active provider.
cd /opt/gsz
node <<'EOF'
require('dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
function parseFrom(s){ s=String(s||'').trim(); const m=s.match(/^\s*(.*?)\s*<\s*([^>]+)\s*>\s*$/); if(m){ return {name:(m[1]||'').replace(/^"|"$/g,'').trim()||'Galaxy Subz x Zayron', email:m[2].trim()}; } return {name:'Galaxy Subz x Zayron', email:s}; }
(async()=>{
 try{
  await pool.query("CREATE TABLE IF NOT EXISTS email_providers(id SERIAL PRIMARY KEY, label TEXT NOT NULL DEFAULT '', provider TEXT NOT NULL DEFAULT 'brevo', api_key TEXT NOT NULL DEFAULT '', from_name TEXT NOT NULL DEFAULT '', from_email TEXT NOT NULL DEFAULT '', region TEXT NOT NULL DEFAULT '', is_active BOOLEAN NOT NULL DEFAULT false, last_status TEXT NOT NULL DEFAULT '', last_tested_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())");
  const cnt=(await pool.query("SELECT count(*)::int n FROM email_providers")).rows[0].n;
  if(cnt===0){
    const key=process.env.BREVO_API_KEY||'';
    const f=parseFrom(process.env.GSZ_SMTP_FROM||process.env.GSZ_MAIL_FROM||'');
    if(key && f.email){
      await pool.query("INSERT INTO email_providers(label,provider,api_key,from_name,from_email,is_active,last_status) VALUES($1,'brevo',$2,$3,$4,true,'migrated from current config')",['Brevo (current)',key,f.name,f.email]);
      console.log('Seeded ACTIVE Brevo provider ('+f.email+')');
    } else { console.log('No env Brevo config found; table created empty'); }
  } else { console.log('Table already has '+cnt+' provider(s); no seed'); }
  const rows=(await pool.query("SELECT id,label,provider,from_email,is_active,CASE WHEN length(api_key)>0 THEN 'set' ELSE 'empty' END keystate FROM email_providers ORDER BY id")).rows;
  rows.forEach(r=>console.log('  '+JSON.stringify(r)));
 }catch(e){ console.log('ERR '+e.message); }
 process.exit(0);
})();
EOF
echo DONE
