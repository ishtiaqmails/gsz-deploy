#!/usr/bin/env bash
# stepAdminInstrProbe.sh — READ-ONLY. Can How-to-Use (instructions) + Warranty be edited per
# product/plan in the website admin today, and are they saved? Check the editor template inputs
# and the adminCatalog save, plus the columns + whether current products actually have values.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== columns that could hold How-to-Use / Warranty ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const pc=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='products' AND column_name IN ('instructions','warranty','delivery_note','note')\")).rows.map(x=>x.column_name);
  console.log('products:', pc.join(', ')||'(none)');
  const pp=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='product_plans' AND column_name IN ('warranty','delivery_instructions','product_note')\")).rows.map(x=>x.column_name);
  console.log('product_plans:', pp.join(', ')||'(none)');
  const stats=(await p.query(\"SELECT count(*) total, count(*) FILTER (WHERE COALESCE(instructions,'')<>'') has_instr, count(*) FILTER (WHERE COALESCE(warranty,'')<>'') has_warr FROM products\")).rows[0];
  console.log('products with instructions set:', stats.has_instr+'/'+stats.total, '| with warranty:', stats.has_warr+'/'+stats.total);
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"

echo ""
echo "=== editor template inputs (name= instructions / warranty / delivery_instructions) ==="
for T in views/admin/product_edit.ejs; do
  [ -f "$T" ] && { echo "[$T]"; grep -nE "name=\"instructions\"|name=\"warranty\"|name=\"plan_warranty\"|name=\"delivery_instructions\"|Instructions|Warranty|How to use" "$T" | head -20; } || echo "$T not found";
done

echo ""
echo "=== does adminCatalog SAVE instructions/warranty? ==="
grep -nE "instructions|warranty|delivery_instructions" routes/adminCatalog.js | head -20
