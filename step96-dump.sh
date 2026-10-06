#!/usr/bin/env bash
# step96-dump — READ-ONLY. Pulls the current home/app/product/order bits for the
# remaining Batch 1 fixes (toast, delivered counter, category count, mobile cut,
# track credentials, duplicate MAC). Changes nothing.
set -euo pipefail
APP=/opt/gsz
cd "$APP"

echo "========== views/home.ejs (FULL) =========="
cat views/home.ejs
echo
echo "========== app.js: toast / toss / counter / delivered / drawer cats =========="
grep -nE "toss|toast|delivered|deliver|counter|Counter|setInterval|setTimeout|buildDrawerCats|statsBand|ticker" public/js/app.js | head -60
echo
echo "========== app.js: the toast + counter function bodies =========="
awk '/function .*[Tt]oss|function .*[Tt]oast|statsBand|delivered|ticker/{print NR": "$0}' public/js/app.js | head -40
echo
echo "========== product.ejs: MAC fields =========="
grep -nE "mac|MAC|macIn|macBtn|mac-box|needMac|NEEDMAC|prefillMac" views/product.ejs
echo
echo "========== order.ejs: credentials block =========="
grep -nE "delivered_credentials|creds|credential" views/order.ejs
sed -n '100,112p' views/order.ejs
echo
echo "==> step96-dump done (read-only)"
