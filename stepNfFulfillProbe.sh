#!/usr/bin/env bash
# stepNfFulfillProbe.sh — READ-ONLY. Dump the two files I must edit to finish Netflix auto-assign:
# lib/deliver.js (full, 116 lines) and lib/nfPortal.js (full). Plus confirm products.nf_enabled.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== products: nf_enabled + relevant cols ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const c=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='products' AND column_name IN ('nf_enabled','req_otp','has_link','renewable')\")).rows.map(x=>x.column_name);
  console.log('products flags present:', c.join(', ')||'(none)');
  const pd=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='product_plans' AND column_name IN ('duration_value','duration_unit')\")).rows.map(x=>x.column_name);
  console.log('plan duration cols:', pd.join(', ')||'(none)');
  const inv=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='inventory_items' ORDER BY ordinal_position\").catch(()=>({rows:[]}))).rows.map(x=>x.column_name);
  console.log('inventory_items cols:', inv.join(', ')||'(table missing)');
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"

echo ""
echo "########## lib/deliver.js ##########"
cat -n lib/deliver.js
echo ""
echo "########## lib/nfPortal.js ##########"
cat -n lib/nfPortal.js
