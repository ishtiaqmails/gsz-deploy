#!/usr/bin/env bash
# READ-ONLY. Where zayron's plans/prices + content types come from, and galaxyzayron slug<->sku for counts map.
Z=/opt/zayron; cd "$Z"
echo "### zayron: server plans/prices source (admin + render) ###"
grep -nE "plan|price|duration|cp_|plans_json|country_prices" lib/data.js | head -20
echo
echo "### zayron checkout: content types (family/adult) source ###"
grep -nE "family|adult|ct=|content|types|/api/products" routes/checkout.js | head -20
echo
echo "### zayron: does it read bot product plans/types anywhere? (ctAvail etc) ###"
grep -rnE "getProducts|\.plans|\.types|plan_key|ctAvail|resolvePackage" routes/checkout.js lib/orderDispatch.js | head -20
echo
echo "============ galaxyzayron products: slug <-> sku <-> panel ============"
(cd /opt/gsz && node -e "const{pool}=require('./db');pool.query('SELECT slug, sku, iptv_panel_id, name FROM products WHERE delivery_type=\$1 ORDER BY slug',['iptv']).then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e=>{console.log('try2:',e.message);pool.query('SELECT slug,name FROM products ORDER BY slug LIMIT 40').then(r=>{r.rows.forEach(x=>console.log(JSON.stringify(x)));process.exit(0)}).catch(e2=>{console.log('ERR',e2.message);process.exit(0)})})" 2>/dev/null) || echo "(gsz db require failed — needs dotenv path)"
echo DONE
