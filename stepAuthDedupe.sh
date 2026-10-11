#!/usr/bin/env bash
# Galaxy — de-duplicate the account auth buttons. The Hub is now the single auth surface:
#  • Hub footer: shows "Sign Out" when logged in; nothing when logged out (the sign-in form
#    in the Hub body already offers Sign In + Create Account with cross-links).
#  • Mobile Quick Access sheet: its duplicate Sign In / Create Account / Sign Out row removed
#    (the "My Account" tile opens the Hub). No more repeated buttons across the models.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
NAV=views/partials/app_nav.ejs
cp -f "$HM" "$HM.bak.$TS"; cp -f "$NAV" "$NAV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; cp -f "$NAV.bak.$TS" "$NAV"; }
trap restore ERR
cp -f "$SRC/hub_model.ejs" "$HM"
cp -f "$SRC/app_nav.ejs" "$NAV"
node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok (hub + nav)');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — single auth surface: one Sign Out (Hub footer), one Sign In / Create Account (Hub form). No duplicates."
