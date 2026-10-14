#!/usr/bin/env bash
# stepNfPlanProbe.sh — READ-ONLY. Prints exactly what I need to add per-plan Netflix
# Kind+Tier cleanly: product_plans columns, the Netflix-detect columns on products,
# and the route file + the plan load/save blocks. Changes nothing.
set -euo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "=== product_plans columns ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const pl=(await p.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='product_plans' ORDER BY ordinal_position\")).rows;
  console.log(pl.map(x=>x.column_name+':'+x.data_type).join(' | '));
  const pr=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='products' AND (column_name ILIKE '%netflix%' OR column_name IN ('delivery_type','code_source','category_id','product_type','kind'))\")).rows;
  console.log('products netflix-ish cols:', pr.map(x=>x.column_name).join(', ')||'(none)');
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"

echo ""
echo "=== route file that renders/saves products ==="
F=$(grep -rlE "adm_product_edit|/admin/products/save" routes/ 2>/dev/null | head -1)
echo "FILE: ${F:-NOT FOUND}"
[ -z "${F:-}" ] && exit 0

echo ""
echo "--- plan LOAD (SELECT ... product_plans) ---"
grep -nE "product_plans" "$F" | head -8

echo ""
echo "--- render adm_product_edit (what vars it passes) ---"
grep -nE "adm_product_edit" "$F" | head

echo ""
echo "--- save handler: plan INSERT/UPDATE + how plan_* fields are read ---"
grep -nE "plan_label|plan_price|plan_id|INTO product_plans|UPDATE product_plans|req.body.plan" "$F" | head -20

echo ""
echo "--- how it knows a product is Netflix (code_source/delivery_type/portal) ---"
grep -nE "code_source|delivery_type|portal|netflix" "$F" | head -12
