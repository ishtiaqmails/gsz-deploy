#!/usr/bin/env bash
# Galaxy — two things in one deploy:
#  1) In-Hub email verification (mirrors WhatsApp): ajax POST /account/tools/email/send +
#     /account/tools/email/verify (reuse sendEmailCode + customer_tokens email_verify);
#     Account tab shows a "Verify your email" card -> code -> verified, with Resend;
#     changing the email re-renders so the card reappears.
#  2) Quick Access is NO LONGER product/plan-aware — all tools show for every customer
#     again (home band, mobile sheet, Hub tabs). The Trials + Account tabs stay.
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
node "$SRC/patch_emailverify.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/hub_model.ejs" "$HM"
cp -f "$SRC/app_nav.ejs" "$NAV"
cp -f "$SRC/customer_tools.ejs" "$CT"
node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$NAV','$CT'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok (hub + nav + band)');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — in-Hub email verification live; Quick Access shows all tools for all customers again."
