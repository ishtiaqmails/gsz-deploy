#!/usr/bin/env bash
# stepInstrBullets.sh — auto-bullet Delivery instructions (admin) + bulleted hub display.
#   views/admin/product_model.ejs : .p_dinstr auto-bullets; loads bulletised, saves clean lines
#   views/partials/hub_model.ejs  : order delivery_instructions render as a bulleted list
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-instrbul-$TS"; cd "$GSZ"
PM=views/admin/product_model.ejs; HB=views/partials/hub_model.ejs
mkdir -p "$BK/views/admin" "$BK/views/partials"
cp "$GSZ/$PM" "$BK/$PM"; cp "$GSZ/$HB" "$BK/$HB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$PM" "$GSZ/$PM"; cp "$BK/$HB" "$GSZ/$HB"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch product_model.ejs + hub_model.ejs"
node "$SRC/patch_instrbullets.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$PM','$GSZ/$HB'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:f});});console.log('   both views compile');"
grep -q 'function pmWireBullets(' "$GSZ/$PM" && echo "   auto-bullet wired"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Delivery instructions auto-bullet in the Product Model; saved as clean lines; every channel adds its own bullet. Hard-refresh the admin once."
