#!/usr/bin/env bash
# Galaxy Hub — Deploy R: remove the customer dashboard. GET /account now redirects straight into the
# shared Hub model (home + ?tool=purchases) instead of rendering a dashboard page — the Hub / Quick
# Access already covers subscriptions, access, renew, trials, claim and account. The /account/tools/*
# and /account/order/:no/* APIs the Hub relies on are NOT touched.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
ACC=routes/account.js
cp -f "$ACC" "$ACC.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$ACC.bak.$TS" "$ACC"; }
trap restore ERR
node "$SRC/patch_accredirect.js" "$GSZ"
node --check "$ACC"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy R: /account opens the Hub model; customer dashboard removed from the flow."
