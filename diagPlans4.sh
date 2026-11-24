#!/usr/bin/env bash
# diagPlans4 — is sv.plans manual (DB column) or bridge-derived? And do bot plan prices == retail prices?
# Uses the app's own db pool so creds work. Read-only.
set -e
cd /opt/zayron
echo "### how lib/data.js builds sv.plans ###"
grep -n "plans" lib/data.js | head -30 || true
echo
echo "--- context around each plans line in lib/data.js ---"
node -e "
const fs=require('fs'); const s=fs.readFileSync('lib/data.js','utf8').split('\n');
s.forEach((l,i)=>{ if(/plans/.test(l)){ console.log('L'+(i+1)+': '+l.trim()); } });
" 2>&1 | head -40
echo
echo "### servers table: plan/price columns + 3 mapped IPTV rows, with their BOT product plans ###"
node -e "
const { pool } = require('./db'); const api=require('./lib/gszApi');
(async()=>{
  try{
    const cols=(await pool.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='servers' ORDER BY ordinal_position\")).rows.map(c=>c.column_name);
    console.log('server cols:', cols.join(', '));
    const rows=(await pool.query('SELECT id,name,slug,bot_sku,reseller_pid,active FROM servers WHERE bot_sku IS NOT NULL ORDER BY id LIMIT 3')).rows;
    const prod=await api.getProducts(); const plist=(prod&&prod.products)||[];
    for(const r of rows){
      const bp=plist.find(y=>String(y.sku)===String(r.bot_sku));
      console.log('\n--- '+r.name+' (slug='+r.slug+', bot_sku='+r.bot_sku+') ---');
      // show DB-stored plans column if it exists
      if(cols.includes('plans')){ const pr=(await pool.query('SELECT plans FROM servers WHERE id=$1',[r.id])).rows[0]; console.log('DB servers.plans:', JSON.stringify(pr&&pr.plans)); }
      console.log('BOT product.plans:', bp?JSON.stringify(bp.plans):'(no bot product matched)');
    }
  }catch(e){ console.log('err:', e.message); }
  process.exit(0);
})();
" 2>&1 | head -80
echo DONE
