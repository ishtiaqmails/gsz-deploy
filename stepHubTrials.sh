#!/usr/bin/env bash
# stepHubTrials.sh — premium per-type trial detail inside the Galaxy Hub (phone + desktop).
#   routes/account.js            : expose `fields` in /account/tools/trials JSON
#   views/partials/hub_model.ejs : .th* styles + renderTrialCred() + use it in trialDetail
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-hubtrials-$TS"; cd "$GSZ"
AC=routes/account.js; HB=views/partials/hub_model.ejs
mkdir -p "$BK/routes" "$BK/views/partials"
cp "$GSZ/$AC" "$BK/$AC"; cp "$GSZ/$HB" "$BK/$HB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AC" "$GSZ/$AC"; cp "$BK/$HB" "$GSZ/$HB"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch account.js + hub_model.ejs"
node "$SRC/patch_hubtrials.js" "$GSZ"
node --check "$GSZ/$AC" && echo "   account.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HB','utf8'),{filename:'$GSZ/$HB'});console.log('   hub_model.ejs compiles');"
grep -q 'function renderTrialCred(t){' "$GSZ/$HB" && echo "   renderTrialCred present"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Galaxy Hub trial detail is premium per-type + responsive. Hard-refresh the page once to load the new hub."
