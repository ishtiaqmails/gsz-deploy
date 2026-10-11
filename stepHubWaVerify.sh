#!/usr/bin/env bash
# Galaxy Hub — WhatsApp verification now lives INSIDE the Hub model (desktop popup + mobile
# app-sheet, same as everything else). Adds: a "Verify your WhatsApp" card at the top of the
# Account tab when unverified, a full verify flow (code → open WhatsApp → auto-detect → ✓),
# and a verify gate on the Free IPTV Trials tab. Backend endpoints already exist; UI-only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR
cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub_model ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — customers can now verify WhatsApp from Account (and from the Trials gate), fully in-model."
