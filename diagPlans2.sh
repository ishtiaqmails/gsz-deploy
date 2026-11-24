#!/usr/bin/env bash
# diagPlans2 — show a bot product that HAS a plans array (duration/price structure), and how the live
# zayron server/checkout page builds its duration picker. Read-only.
set -e
cd /opt/zayron
echo "### bot products that carry a plans array ###"
node -e "
const api=require('./lib/gszApi');
(async()=>{
  try{
    const r=await api.getProducts(); const list=(r&&r.products)||[];
    const withPlans=list.filter(p=>Array.isArray(p.plans)&&p.plans.length);
    console.log('products with plans:', withPlans.length, '/', list.length);
    const ex=withPlans.find(p=>/iptv|tv|b1g|filex|zain|hexa|star|zum|bos/i.test(p.name))||withPlans[0];
    if(ex){ console.log('example name:', ex.name); console.log('example keys:', Object.keys(ex).join(', ')); console.log('example.plans JSON:', JSON.stringify(ex.plans,null,1)); console.log('example full (minus big):', JSON.stringify(Object.assign({},ex,{needs:undefined,retrieve:undefined}),null,1)); }
    else console.log('no product has a plans array');
  }catch(e){ console.log('bridge err:', e.message); }
  process.exit(0);
})();
" 2>&1 | head -90
echo
echo "### live code: how durations/plans are rendered (live .js/.ejs only) ###"
grep -rln "\.plans\|duration\|plan_label\|months\|1 Month\|validity" --include=*.js --include=*.ejs routes lib views 2>/dev/null | grep -v node_modules || true
echo
echo "### the server/product page route (plan picker build) ###"
grep -rn "server/:slug\|/server/\|planPicker\|durations\|\.plans" --include=*.js routes lib 2>/dev/null | grep -v node_modules | head -30 || true
echo DONE
