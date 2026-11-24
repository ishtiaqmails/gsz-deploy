#!/usr/bin/env bash
set -e
cd /opt/zayron
node - <<'NODE'
const { pool } = require('./db'); const api=require('./lib/gszApi');
(async()=>{ try{
  const prod=await api.getProducts(); const plist=(prod&&prod.products)||[];
  const srv=(await pool.query('SELECT id,name,bot_sku FROM servers ORDER BY name')).rows;
  for(const s of srv){
    const labs=(await pool.query("SELECT string_agg(label, ', ' ORDER BY sort) l FROM server_plans WHERE server_id=$1 AND price>0",[s.id])).rows[0].l||'(none)';
    let ct='UNMAPPED';
    if(s.bot_sku){ const bp=plist.find(y=>String(y.sku)===String(s.bot_sku)); ct=(bp&&Array.isArray(bp.types))?bp.types.map(x=>x.key).join('+'):'no-types'; }
    console.log(' - '+s.name.padEnd(22)+' | '+ct.padEnd(14)+' | '+labs);
  }
}catch(e){console.log(e.message)} process.exit(0); })();
NODE
