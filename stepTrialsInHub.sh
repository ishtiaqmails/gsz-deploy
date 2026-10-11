#!/usr/bin/env bash
# Galaxy — Part 2B: IPTV Free Trial now runs inside the Hub model (follows our models).
#  • The header "IPTV Free Trial" button opens the Hub Trials tab (not the old trial modal).
#  • Trial claim happens in-Hub (fetch /api/trials, claim via /trials/claim); an unverified
#    customer is sent to the in-Hub Verify flow — never the old /account/whatsapp, never checkout.
#  • Belt-and-suspenders: routes/trials.js non-ajax unverified redirect -> /?tool=trials.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
TR=routes/trials.js
cp -f "$HM" "$HM.bak.$TS"; cp -f "$TR" "$TR.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; cp -f "$TR.bak.$TS" "$TR"; }
trap restore ERR
cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub ejs ok');"
node "$SRC/patch_trialredirect.js" "$GSZ"
node --check "$TR"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — IPTV Free Trial runs in the Hub; unverified -> in-Hub Verify (no old page, no checkout)."
