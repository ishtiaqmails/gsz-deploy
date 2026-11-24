#!/usr/bin/env bash
# READ-ONLY. Everything Batch A (checkout) needs: render, submit/verify, methodsFor, paySalt, schema, admin editor, gsz buffer.
Z=/opt/zayron; cd "$Z"
echo "### methodsFor (66-100) ###"; sed -n '66,100p' routes/checkout.js
echo; echo "### payment render incl your-details + screenshot (280-330) ###"; sed -n '280,330p' routes/checkout.js
echo; echo "### submit/verify (460-520) ###"; sed -n '460,520p' routes/checkout.js
echo; echo "### lib/paySalt.js (full) ###"; cat -n lib/paySalt.js 2>/dev/null
echo; echo "### payment_methods columns ###"
node -e "const{pool}=require('./db');pool.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='payment_methods' ORDER BY ordinal_position\").then(r=>{r.rows.forEach(x=>console.log(x.column_name,'|',x.data_type));process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})"
echo; echo "### orders columns (proof fields) ###"
node -e "const{pool}=require('./db');pool.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND (column_name ILIKE '%proof%' OR column_name ILIKE '%pay%' OR column_name ILIKE '%screenshot%')\").then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})"
echo; echo "### admin payment_methods editor ###"; grep -nE "payment_methods|buffer|iban|Account Number|method name|/admin/pay" routes/admin.js | head -15
echo; echo "### gsz_pricing resolve (85-120) ###"; sed -n '85,120p' /opt/gsz/lib/gsz_pricing.js 2>/dev/null
echo DONE
