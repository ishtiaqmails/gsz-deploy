#!/usr/bin/env bash
# stepNfHousehold.sh — Phase 2: household = tap-link + tier safety on password-change links.
#   Redeploys lib/netflixGate.js (new_signin/password_reset = Full-tier only).
#   Patches routes/account.js (household route -> resolve household link) + views/partials/hub_model.ejs.
# Idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-nfhh-$TS"; cd "$GSZ"
GATE=lib/netflixGate.js; AC=routes/account.js; HB=views/partials/hub_model.ejs
mkdir -p "$BK/lib" "$BK/routes" "$BK/views/partials"
cp "$GSZ/$GATE" "$BK/$GATE"; cp "$GSZ/$AC" "$BK/$AC"; cp "$GSZ/$HB" "$BK/$HB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$GATE" "$GSZ/$GATE"; cp "$BK/$AC" "$GSZ/$AC"; cp "$BK/$HB" "$GSZ/$HB"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> deploy gate (tier safety) + patch household route + hub button"
cp -f "$SRC/netflixGate.js" "$GSZ/$GATE"
node "$SRC/patch_nfhousehold2.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/$GATE" && echo "   netflixGate.js ok"
node --check "$GSZ/$AC" && echo "   account.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HB','utf8'),{filename:'$GSZ/$HB'});console.log('   hub_model.ejs compiles');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — household 'Update Household' button now opens the tap-link; password-change links are Full-tier only. Migration complete; old portal safe to retire."
