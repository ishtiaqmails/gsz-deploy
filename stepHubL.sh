#!/usr/bin/env bash
# Galaxy Hub — Deploy L: My Account tab is now compact (tight single-line fields) with a pencil
# EDIT icon instead of the full-text "Change" buttons, and a copy icon for the referral code.
# Copies the updated Hub + checkout partials from libsrc — this is a SUPERSET of Deploy K
# (it also carries the password/email/file-input styling + coupon-hint removal), so running L
# alone is enough whether or not K was run.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
CM=views/partials/checkout_model.ejs
cp -f "$HM" "$HM.bak.$TS"; cp -f "$CM" "$CM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; cp -f "$CM.bak.$TS" "$CM"; }
trap restore ERR
cp -f "$SRC/hub_model.ejs" "$HM"
cp -f "$SRC/checkout_model.ejs" "$CM"
node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$CM'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy L: My Account compact + edit/copy icons (includes all Deploy K field fixes)."
