#!/usr/bin/env bash
# Galaxy — in-Hub email verification model (mirrors the WhatsApp one):
#  • New ajax endpoints: POST /account/tools/email/send + /account/tools/email/verify
#    (reuse the existing sendEmailCode + customer_tokens email_verify logic).
#  • Account tab: "Verify your email" card when unverified -> send code -> enter 6-digit code
#    -> verified, with Resend. Changing the email re-renders so the Verify card reappears.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/account.js
HM=views/partials/hub_model.ejs
cp -f "$AC" "$AC.bak.$TS"; cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR
node "$SRC/patch_emailverify.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — customers can verify (and re-verify after changing) their email right inside the Hub."
