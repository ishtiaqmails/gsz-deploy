#!/usr/bin/env bash
# Galaxy — Part 2A: Quick Access is now entitlement-aware across all surfaces.
#  • New GET /account/tools/entitlements -> {orders, access, renewable}.
#  • Hub model: added Trials + Account tabs (so all tools are reachable); product-aware
#    tabs (Orders, Access, Renew, Claim) show only when the customer qualifies.
#  • Home "Galaxy Hub" band + mobile Quick Access sheet: product-aware tiles hidden
#    unless relevant. Free Trials, Account and Support always shown.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/account.js
HM=views/partials/hub_model.ejs
NAV=views/partials/app_nav.ejs
CT=views/partials/customer_tools.ejs
for f in "$AC" "$HM" "$NAV" "$CT"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "$AC" "$HM" "$NAV" "$CT"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR

node "$SRC/patch_entitlements.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/hub_model.ejs" "$HM"
cp -f "$SRC/app_nav.ejs" "$NAV"
cp -f "$SRC/customer_tools.ejs" "$CT"
node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$NAV','$CT'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok (hub + nav + band)');"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Quick Access now shows all tools, product-aware. New customers see a clean set; customers see only what applies to their purchases."
