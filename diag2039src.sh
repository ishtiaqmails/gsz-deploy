#!/usr/bin/env bash
# diag2039src — GSZ-2039 source/product + how own-inventory orders paid via a bot payment method get verified. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### GSZ-2039 source + product + amounts ###"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT order_no,source,status,product_name,plan_label,amount_pkr,method_key,method_name,bot_sku,product_id FROM orders WHERE order_no='GSZ-2039'\").then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -4
echo
echo "### how 'verifying' + source is set at order creation (startStatus / source) ###"
grep -n "startStatus\|source:\|,source,\|botPay\|status='verifying'\|INSERT INTO orders" routes/checkout.js | head -20
echo
echo "### the verify drainer + reverify source filter (already seen) + what delivers an inventory (non-bot) order ###"
sed -n '578,620p' routes/checkout.js
echo
echo "### how a non-bot (inventory) 'paid' order is fulfilled/delivered ###"
grep -n "inventory\|own_stock\|manual\|source==='manual'\|source === 'manual'\|deliverInventory\|assignStock\|nf_assign\|source!=='bot'" routes/checkout.js | head -20
echo DONE
