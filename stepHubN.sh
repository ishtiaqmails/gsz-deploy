#!/usr/bin/env bash
# Galaxy Hub — Deploy N (payment logo tiles): payment methods now render as selectable SQUARE TILES
# with logos in checkout (single + cart). Admin → Payments gets a per-method logo uploader, the
# pay-methods API returns each method's logo (by key), and a monogram tile is shown for methods with
# no logo yet. Adds payment_methods.logo column (idempotent).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AP=routes/adminPayments.js
APV=views/admin/payments.ejs
ACC=routes/account.js
CM=views/partials/checkout_model.ejs
cp -f "$AP" "$AP.bak.$TS"; cp -f "$APV" "$APV.bak.$TS"; cp -f "$ACC" "$ACC.bak.$TS"; cp -f "$CM" "$CM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AP.bak.$TS" "$AP"; cp -f "$APV.bak.$TS" "$APV"; cp -f "$ACC.bak.$TS" "$ACC"; cp -f "$CM.bak.$TS" "$CM"; }
trap restore ERR

# 1) DB column (idempotent; harmless even if the rest rolls back)
export PGPASSWORD=$(sed -n 's/^DB_PASS=//p' .env); DBU=$(sed -n 's/^DB_USER=//p' .env); DBN=$(sed -n 's/^DB_NAME=//p' .env); DBH=$(sed -n 's/^DB_HOST=//p' .env)
psql -h "${DBH:-127.0.0.1}" -U "$DBU" -d "$DBN" -c "ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS logo text;"

# 2) files
cp -f "$SRC/adminPayments.js" "$AP"
cp -f "$SRC/adm_payments.ejs" "$APV"
cp -f "$SRC/checkout_model.ejs" "$CM"
node "$SRC/patch_paylogos.js" "$GSZ"

# 3) validate before restart
node --check "$AP"
node --check "$ACC"
node -e "const ejs=require('ejs'),fs=require('fs');['$APV','$CM'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy N: payment logo tiles in checkout + logo uploader in Admin → Payments."
