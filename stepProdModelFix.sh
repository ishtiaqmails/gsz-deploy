#!/usr/bin/env bash
# Galaxy — Product Model, STEP 4b (fixes):
#   - required_fields now derived from bot delivery_type (MAC / activation email / link+qty)
#   - model no longer auto-adds Email/Password custom fields onto EXISTING inventory plans on edit
# Patches routes/adminCatalog.js + refreshes the model partial. Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/adminCatalog.js; MODEL=views/admin/product_model.ejs
cp -f "$AC" "$AC.bak.$TS"; cp -f "$MODEL" "$MODEL.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$MODEL.bak.$TS" "$MODEL"; }
trap restore ERR
node "$SRC/patch_reqfields.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/adm_product_model.ejs" "$MODEL"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/product_model.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Step 4b: required-fields + custom-field auto-add fixes applied."
