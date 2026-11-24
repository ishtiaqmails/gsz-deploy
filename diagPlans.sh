#!/usr/bin/env bash
# diagPlans — how durations/plans currently work on zayron, and whether the mapped bot product exposes
# durations we could auto-map. Read-only.
set -e
cd /opt/zayron
echo "### server_plans table: columns + sample ###"
node -e "
const {Pool}=require('pg'); const p=new Pool();
(async()=>{
  try{
    const cols=(await p.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='server_plans' ORDER BY ordinal_position\")).rows;
    console.log('columns:', cols.map(c=>c.column_name+':'+c.data_type).join(', ')||'(no such table)');
    const rows=(await p.query('SELECT * FROM server_plans ORDER BY 1 LIMIT 12')).rows;
    console.log('rows:', JSON.stringify(rows,null,1));
  }catch(e){ console.log('server_plans err:', e.message); }
  process.exit(0);
})();
" 2>&1 | head -60
echo
echo "### where server_plans / durations are read in code ###"
grep -rln "server_plans\|duration_days\|durations\|plan_label\|months" routes lib 2>/dev/null | grep -v node_modules | head || true
echo
echo "### gsz bridge: one product's FULL shape (does it carry durations/plans/validity?) ###"
node -e "
const api=require('./lib/gszApi');
(async()=>{
  try{
    const r=await api.getProducts();
    const list=(r&&r.products)||[];
    console.log('product count:', list.length);
    console.log('first product keys:', list[0]?Object.keys(list[0]).join(', '):'(none)');
    console.log('sample product JSON:', JSON.stringify(list[0],null,1));
    // look for any duration-ish field across products
    const dkeys=new Set();
    list.forEach(p=>Object.keys(p).forEach(k=>{ if(/dur|month|plan|valid|period|day|price|tier/i.test(k)) dkeys.add(k); }));
    console.log('duration/plan-ish keys seen:', [...dkeys].join(', ')||'(none)');
  }catch(e){ console.log('bridge err:', e.message); }
  process.exit(0);
})();
" 2>&1 | head -80
echo DONE
