#!/usr/bin/env bash
# diagPlans3 — how the customer /server/:slug plan picker is built today, how servers store plans/prices,
# and how paidToggle maps a chosen plan to the bot. Read-only.
set -e
cd /opt/zayron
echo "### servers table: plan/price-ish columns + one sample row (truncated) ###"
node -e "
const fs=require('fs'); const {Pool}=require('pg');
const env={}; fs.readFileSync('.env','utf8').split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/i); if(m) env[m[1]]=m[2].replace(/^[\"']|[\"']$/g,'').trim();});
const p=new Pool({host:env.DB_HOST||'127.0.0.1',port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{
  try{
    const cols=(await p.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='servers' ORDER BY ordinal_position\")).rows;
    console.log('server cols:', cols.map(c=>c.column_name).join(', '));
    const r=(await p.query('SELECT * FROM servers ORDER BY id LIMIT 1')).rows[0]||{};
    const slim={}; for(const k of Object.keys(r)){ let v=r[k]; if(typeof v==='string'&&v.length>120) v=v.slice(0,120)+'...'; slim[k]=v; }
    console.log('sample row:', JSON.stringify(slim,null,1));
  }catch(e){ console.log('db err:', e.message); }
  process.exit(0);
})();
" 2>&1 | head -70
echo
echo "### /server/:slug route render (where plan options are built) ###"
grep -rnE "/server/:|app\.get\('/server|router\.get\('/server|planOptions|product\.plans|\.plans|buildPlans" server.js routes lib 2>/dev/null | grep -v node_modules | head -25 || true
echo
echo "### lib/paidToggle.js (full) — plan->bot mapping ###"
sed -n '1,80p' lib/paidToggle.js
echo DONE
