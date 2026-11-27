#!/usr/bin/env bash
# diagRenewPort — galaxyzayron's renewal entry (account renew button + checkout renew param + line capture) and
# zayron's account order list + checkout structure, to port IPTV renewal to zayron. READ-ONLY.
set +e
echo "########## galaxyzayron: how renewal is initiated (account -> renew) ##########"
cd /opt/gsz
grep -rn "renew\b\|renew=\|Renew\|renew_of\|renew_line\|/checkout.*renew\|data-renew\|renewable" routes/account.js views 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | grep -iE "renew" | head -20
echo "--- how the checkout captures renew_line from an existing order/line (account tools) ---"
grep -rn "renew_line\|line_user\|delivered_credentials\|iptvLookup\|parseCreds\|renew_of\|renewable" routes/account.js routes/checkout.js 2>/dev/null | grep -iE "renew|iptvLookup" | head -15
echo
echo "########## zayron: account order list (where customer sees orders) ##########"
cd /opt/zayron
grep -rn "FROM orders\|order.*status\|line_user\|Renew\|renew\|delivered\|expires_at\|/account/orders\|my orders\|order list" routes/account.js 2>/dev/null | grep -iE "orders|renew|delivered|expires" | head -20
echo
echo "########## zayron: checkout entry (server/plan -> order), to add a renew mode ##########"
grep -n "router.get\|router.post\|INSERT INTO orders\|server_id\|plan_label\|content_type\|renew" routes/checkout.js | head -25
echo
echo "########## zayron orders: renewal-relevant columns (already present?) ##########"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND (column_name LIKE '%renew%' OR column_name LIKE '%line%' OR column_name='kind' OR column_name='field_data')\").then(r=>{console.log(r.rows.map(x=>x.column_name).join(', '));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -3
echo DONE
