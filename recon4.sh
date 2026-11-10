#!/usr/bin/env bash
# recon4 : READ-ONLY. Finds where the top announcement bar + the mid-page stats
# bar live, the shell top insertion point, and confirms Node fetch. Changes nothing.
cd /opt/gsz

echo "=== where is the offer/announcement bar rendered? ==="
grep -rn "mq-ready\|class=\"offer\|offer mq\|MEGA SALE\|announcement\|promo_bar\|offerBar" views --include=*.ejs | head -15

echo; echo "=== where is the .stats bar (to remove)? ==="
grep -rn "stats reveal\|class=\"stats\|Average customer rating\|Orders delivered\|Since 2021" views --include=*.ejs | head -15

echo; echo "=== shell top partial: store_top.ejs (first 45 lines, insertion point) ==="
sed -n '1,45p' views/partials/store_top.ejs

echo; echo "=== how store_top / customer_tools are included + what data the shell gets ==="
grep -rn "store_top\|customer_tools" views --include=*.ejs | grep -i include | head
grep -n "site_name\|wa_number\|settings" lib/storefront.js | head -6

echo; echo "=== Node fetch available? ==="
node -e "console.log('fetch:', typeof fetch, '| node', process.version)"
echo "=== recon4 done ==="
