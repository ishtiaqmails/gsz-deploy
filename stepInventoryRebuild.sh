#!/usr/bin/env bash
# Galaxy — Admin rebuild: Inventory / Add Stock section rebuilt in the premium
# mobile + desktop model (modelled on the reseller dashboard's Add Stock).
# Backend engine (routes/adminInventory.js) is unchanged — only the two views are replaced:
#   • /admin/inventory         : stat cards, search, per-product cards with per-plan
#       Available/Sold + Add / Manage / Enable / Disable, line-aligned bulk Add-Stock modal
#       (one box per field + live line counts) and a Set-Fields modal.
#   • /admin/inventory/manage/:planId : Total/Available/Sold cards, All/Available/Sold filters,
#       credentials table, row Edit/Delete, bulk Delete/Move, Clear available.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
L=views/admin/inventory.ejs
M=views/admin/inventory_manage.ejs
cp -f "$L" "$L.bak.$TS"; cp -f "$M" "$M.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$L.bak.$TS" "$L"; cp -f "$M.bak.$TS" "$M"; }
trap restore ERR
cp -f "$SRC/adm_inventory.ejs" "$L"
cp -f "$SRC/adm_inventory_manage.ejs" "$M"
node -e "const ejs=require('ejs'),fs=require('fs');['$L','$M'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok (inventory + manage)');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Admin → Add Stock rebuilt in the premium mobile + desktop model (/admin/inventory)."
