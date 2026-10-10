#!/usr/bin/env bash
# Galaxy Hub — Deploy I (audit): Hub pop-up + in-model auth now SITE-WIDE (hub_model partial,
# included via app_nav), so the Hub/Sign-in/tools work on every page, not just home. The home
# Quick Access band stays home-only. Also fixes Buy Now plan selection (was reading data-plan-idx;
# the pills use data-idx, so it always used plan 0). Partials only — no route changes.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
NAV=views/partials/app_nav.ejs
CM=views/partials/checkout_model.ejs
HM=views/partials/hub_model.ejs
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')

cp -f "$CT" "$CT.bak.$TS"; cp -f "$NAV" "$NAV.bak.$TS"; [ -f "$CM" ] && cp -f "$CM" "$CM.bak.$TS"; [ -f "$HM" ] && cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$CT.bak.$TS" "$CT"; cp -f "$NAV.bak.$TS" "$NAV"; [ -f "$CM.bak.$TS" ] && cp -f "$CM.bak.$TS" "$CM"; [ -f "$HM.bak.$TS" ] && cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR

cp -f "$SRC/hub_model.ejs" "$HM"           # NEW site-wide Hub pop-up + JS (must exist before app_nav renders)
cp -f "$SRC/customer_tools.ejs" "$CT"       # band only now
cp -f "$SRC/checkout_model.ejs" "$CM"       # Buy Now plan-idx fix
cp -f "$SRC/app_nav.ejs" "$NAV"             # includes hub_model + checkout_model
node "$SRC/patch_appnav.js" "$GSZ"

node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$CT','$CM','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy I: Hub + in-model auth are site-wide now; Buy Now uses the selected plan."
