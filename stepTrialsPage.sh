#!/usr/bin/env bash
# stepTrialsPage.sh — premium, per-type, responsive "My Trials" page.
#   lib/trialpoll.js        : persist bot fields into trial_claims.metadata at delivery
#   routes/trials.js        : add metadata to the My Trials query
#   views/account/trials.ejs: premium per-type cards (phone + desktop)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-trialspage-$TS"; cd "$GSZ"
TP=lib/trialpoll.js; TJ=routes/trials.js; TV=views/account/trials.ejs
mkdir -p "$BK/lib" "$BK/routes" "$BK/views/account"
cp "$GSZ/$TP" "$BK/$TP"; cp "$GSZ/$TJ" "$BK/$TJ"; cp "$GSZ/$TV" "$BK/$TV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$TP" "$GSZ/$TP"; cp "$BK/$TJ" "$GSZ/$TJ"; cp "$BK/$TV" "$GSZ/$TV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install files"
cp "$SRC/trialpoll.js"        "$GSZ/$TP"
cp "$SRC/account_trials.ejs"  "$GSZ/$TV"
node "$SRC/patch_trialsmeta.js" "$GSZ"
node --check "$GSZ/$TP" && echo "   trialpoll.js ok"
node --check "$GSZ/$TJ" && echo "   trials.js ok"
# EJS syntax compile check (view engine already installed)
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$TV','utf8'),{filename:'$GSZ/$TV'});console.log('   trials.ejs compiles');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — My Trials is premium per-type + responsive. New trials store fields; existing ones show the clean raw box until re-claimed."
