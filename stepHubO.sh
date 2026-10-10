#!/usr/bin/env bash
# Galaxy Hub — Deploy O (payment logos, bot-driven): Admin -> Payments now lists your ACTUAL
# reseller-bot payment methods (meezan/binance/nayapay/...) and lets you upload a logo per method.
# Logos live in a dedicated payment_logos registry keyed by the bot's method key, and attach to the
# checkout tiles by key. The reseller bot stays the single source of truth for payment details.
# Supersedes Deploy N's local-table logo approach (and drops that unused column).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AP=routes/adminPayments.js
APV=views/admin/payments.ejs
ACC=routes/account.js
cp -f "$AP" "$AP.bak.$TS"; cp -f "$APV" "$APV.bak.$TS"; cp -f "$ACC" "$ACC.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AP.bak.$TS" "$AP"; cp -f "$APV.bak.$TS" "$APV"; cp -f "$ACC.bak.$TS" "$ACC"; }
trap restore ERR

# 1) DB: logo registry + drop the unused column from Deploy N (both idempotent)
export PGPASSWORD=$(sed -n 's/^DB_PASS=//p' .env); DBU=$(sed -n 's/^DB_USER=//p' .env); DBN=$(sed -n 's/^DB_NAME=//p' .env); DBH=$(sed -n 's/^DB_HOST=//p' .env)
psql -h "${DBH:-127.0.0.1}" -U "$DBU" -d "$DBN" -c "CREATE TABLE IF NOT EXISTS payment_logos(key text PRIMARY KEY, logo text, updated_at timestamptz DEFAULT now());"
psql -h "${DBH:-127.0.0.1}" -U "$DBU" -d "$DBN" -c "ALTER TABLE payment_methods DROP COLUMN IF EXISTS logo;"

# 2) files
cp -f "$SRC/adminPayments.js" "$AP"
cp -f "$SRC/adm_payments.ejs" "$APV"
node "$SRC/patch_paylogos.js" "$GSZ"

# 3) validate before restart
node --check "$AP"
node --check "$ACC"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$APV','utf8'),{filename:process.cwd()+'/'+'$APV'});console.log('  ejs ok');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy O: Admin -> Payments is bot-driven; upload a logo per real bot method."
