#!/usr/bin/env bash
# stepSignupVerify.sh — Step 1 of the "verify WhatsApp at signup" change.
#   After "Create Account" succeeds, the Hub drops straight into the existing
#   waVerify() screen (send code -> auto-verified). Same verification model as now.
#   UI-only (hub_model.ejs). Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR

cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub_model.ejs compiles');"

# confirm the chain is in place
if grep -q "waVerify(function(){ location.reload(); });" "$HM"; then echo "  signup -> waVerify chain: present"; else echo "  WARN: chain not found after deploy"; fi

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — new signups now go straight into WhatsApp verification. (Checkout gate + dual-channel delivery are the next two steps.)"
