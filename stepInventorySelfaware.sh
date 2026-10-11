#!/usr/bin/env bash
# Galaxy — Inventory is now fully SELF-AWARE from the product page:
#   • lists only plans whose type is Inventory (plan source='inventory'), set on the product page
#   • each plan's Add-Stock fields come from that plan's own fields (product_plans.custom_fields)
#     — no separate "Set fields" step in Inventory anymore
# Replaces routes/adminInventory.js (engine) + views/admin/inventory.ejs (list). Manage view unchanged.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
R=routes/adminInventory.js
L=views/admin/inventory.ejs
cp -f "$R" "$R.bak.$TS"; cp -f "$L" "$L.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$R.bak.$TS" "$R"; cp -f "$L.bak.$TS" "$L"; }
trap restore ERR
cp -f "$SRC/adminInventory.js" "$R"
node --check "$R"
cp -f "$SRC/adm_inventory.ejs" "$L"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$L','utf8'),{filename:process.cwd()+'/'+'$L'});console.log('  inventory ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Inventory auto-syncs plans + fields from the product page. Prime Video's Inventory plans now show their fields and the Add dialog matches."
