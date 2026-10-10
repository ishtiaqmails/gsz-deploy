#!/usr/bin/env bash
# Galaxy Hub — Deploy P (payment tiles polish): nicer tile typography (equal-height tiles, amounts
# aligned at the bottom in accent colour), method ORDER is now controllable in Admin -> Payments
# (per-method "Order" number), and a no-store fetch so new logos/order appear instantly. Sets the
# requested order: Meezan (1), NayaPay (2), Binance (3).
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

# 1) DB: order column + set requested sequence (idempotent)
export PGPASSWORD=$(sed -n 's/^DB_PASS=//p' .env); DBU=$(sed -n 's/^DB_USER=//p' .env); DBN=$(sed -n 's/^DB_NAME=//p' .env); DBH=$(sed -n 's/^DB_HOST=//p' .env)
psql -h "${DBH:-127.0.0.1}" -U "$DBU" -d "$DBN" -c "ALTER TABLE payment_logos ADD COLUMN IF NOT EXISTS sort int DEFAULT 100;"
psql -h "${DBH:-127.0.0.1}" -U "$DBU" -d "$DBN" -c "INSERT INTO payment_logos(key,sort) VALUES('meezan',1),('nayapay',2),('binance',3) ON CONFLICT(key) DO UPDATE SET sort=EXCLUDED.sort;"

# 2) files
cp -f "$SRC/adminPayments.js" "$AP"
cp -f "$SRC/adm_payments.ejs" "$APV"
cp -f "$SRC/checkout_model.ejs" "$CM"
node "$SRC/patch_paylogos.js" "$GSZ"

# 3) validate
node --check "$AP"
node --check "$ACC"
node -e "const ejs=require('ejs'),fs=require('fs');['$APV','$CM'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy P: tidier payment tiles + admin-controlled order (Meezan, NayaPay, Binance)."
