#!/usr/bin/env bash
# stepNfPlanProbe.sh — READ-ONLY. Find the admin products route anywhere in the app,
# show how plans (source/bot/portal) are saved, and dump current Netflix plan data so
# per-plan Kind+Tier fits what already exists. Changes nothing. (no pipefail: grep-miss is fine)
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== existing source values + Netflix-ish plans ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const s=(await p.query(\"SELECT COALESCE(source,'(null)') src,count(*) FROM product_plans GROUP BY 1 ORDER BY 2 DESC\")).rows;
  console.log('source counts:', s.map(x=>x.src+'='+x.count).join(' | '));
  const nf=(await p.query(\"SELECT pp.id,pp.product_id,pp.label,pp.source,pp.bot_type,pp.bot_sku,pp.nf_portal_product_id, (SELECT name FROM products WHERE id=pp.product_id) pname FROM product_plans pp WHERE pp.source ILIKE '%portal%' OR pp.nf_portal_product_id IS NOT NULL OR pp.bot_type ILIKE '%netflix%' OR (SELECT name FROM products WHERE id=pp.product_id) ILIKE '%netflix%' ORDER BY pp.product_id, pp.sort LIMIT 25\")).rows;
  console.log('--- Netflix-ish plans (id | product | label | source | bot_type | bot_sku | nf_portal_product_id) ---');
  nf.forEach(r=>console.log([r.id,r.pname,r.label,r.source,r.bot_type,r.bot_sku,r.nf_portal_product_id].map(x=>x==null?'-':x).join(' | ')));
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"

echo ""
echo "=== find admin products route (render + save) anywhere ==="
grep -rlE "adm_product_edit" --include=*.js . 2>/dev/null | grep -v node_modules | head
echo "--- files that write product_plans ---"
grep -rlE "INTO product_plans|UPDATE product_plans" --include=*.js . 2>/dev/null | grep -v node_modules | head

echo ""
F=$(grep -rlE "adm_product_edit" --include=*.js . 2>/dev/null | grep -v node_modules | head -1)
echo "ROUTE FILE: ${F:-NOT FOUND}"
if [ -n "${F:-}" ]; then
  echo "--- how it reads plan fields from req.body (source/bot/portal/label) ---"
  grep -nE "plan_label|plan_price|plan_source|plan_bot|nf_portal|req.body.plan|\.source|bot_type|bot_sku" "$F" | head -25
  echo "--- plan write block (INTO/UPDATE product_plans) ---"
  grep -nE "INTO product_plans|UPDATE product_plans" "$F" | head
  echo "--- render call + vars ---"
  grep -nE "adm_product_edit" "$F" | head
fi

echo ""
echo "=== does the edit template already have a source/bot/portal control? ==="
grep -nE "plan_source|plan_bot|nf_portal|name=\"source\"|Source|Inventory|Portal" views/adm_product_edit.ejs 2>/dev/null | head
