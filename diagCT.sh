#!/usr/bin/env bash
# diagCT — which content types each mapped server's bot product exposes (family/adult), and how checkout +
# server page decide whether to show the Adult option. Read-only.
set -e
cd /opt/zayron
echo "### bot product TYPES per mapped server (family-only vs has-adult) ###"
node -e "
const { pool } = require('./db'); const api=require('./lib/gszApi');
(async()=>{ try{
  const servers=(await pool.query('SELECT name,bot_sku FROM servers WHERE bot_sku IS NOT NULL ORDER BY name')).rows;
  const prod=await api.getProducts(); const plist=(prod&&prod.products)||[];
  for(const s of servers){
    const bp=plist.find(y=>String(y.sku)===String(s.bot_sku));
    const types=(bp&&Array.isArray(bp.types))?bp.types.map(t=>t.key).join('+'):'(no types array)';
    console.log(' -', s.name+':', types);
  }
}catch(e){console.log(e.message)} process.exit(0); })();
"
echo
echo "### ctAvail / content-type logic in code ###"
grep -rn "ctAvail\|content_type\|adult\|family\|\.types\|ct=\|ctAdult\|hasAdult" --include=*.js routes/checkout.js server.js lib/data.js lib/orderDispatch.js 2>/dev/null | grep -v node_modules | head -50 || true
echo
echo "### checkout.js content-type switch render (around the family/adult UI) ###"
grep -n "adult\|family\|content_type\|ct\b\|toggle\|Adult\|Family" routes/checkout.js | head -40 || true
echo DONE
