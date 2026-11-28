#!/usr/bin/env bash
# diagWabotAudit3 — READ-ONLY. Correctly dumps all 20 wa_templates (key + full English body + which
# extra languages are set) to the console. Changes nothing. Small output — paste or attach it.
set +e
G=/opt/gsz
cat > "$G/_tpl_dump.js" <<'JS'
const {Pool}=require('pg');require('dotenv').config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  try{
    const r=(await p.query("SELECT key, body, langs FROM wa_templates ORDER BY key")).rows;
    console.log('TOTAL TEMPLATES: '+r.length+'\n');
    r.forEach(t=>{
      let extra=''; try{ const L=t.langs&&typeof t.langs==='object'?Object.keys(t.langs).filter(k=>t.langs[k]&&String(t.langs[k]).trim()):[]; if(L.length) extra=' [langs: '+L.join(',')+']'; }catch(e){}
      console.log('========================================');
      console.log('KEY: '+t.key+extra);
      console.log('----------------------------------------');
      console.log(t.body||'(empty body)');
      console.log('');
    });
  }catch(e){ console.log('ERR', e.message); }
  await p.end();
})();
JS
( cd "$G" && node "$G/_tpl_dump.js" )
rm -f "$G/_tpl_dump.js"
