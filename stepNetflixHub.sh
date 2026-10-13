#!/usr/bin/env bash
# stepNetflixHub.sh — surface the tiered Netflix codes panel inside the hub (My Purchases).
#   - routes/netflixHub.js: JSON endpoint /account/tools/netflix/:no (reads nf_assignment -> nf_account,
#     Portal codes via nfMail, gated by plan tier via netflixGate). Read-only, owner-checked, fail-safe.
#   - server.js: mount the route (idempotent).
#   - hub_model.ejs: render account/profile creds + allowed codes + Refresh inline in the order detail.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-nfhub-$TS"; cd "$GSZ"
SV=server.js; HM=views/partials/hub_model.ejs; RT=routes/netflixHub.js
mkdir -p "$BK/views/partials" "$BK/routes"
cp "$GSZ/$SV" "$BK/$SV"; cp "$GSZ/$HM" "$BK/$HM"; [ -f "$GSZ/$RT" ] && cp "$GSZ/$RT" "$BK/$RT"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SV" "$GSZ/$SV"; cp "$BK/$HM" "$GSZ/$HM"; [ -f "$BK/$RT" ] && cp "$BK/$RT" "$GSZ/$RT" || rm -f "$GSZ/$RT"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/netflixHub.js" "$GSZ/$RT"
cp -f "$SRC/hub_model.ejs" "$GSZ/$HM"
echo "==> mount route in server.js"
node "$SRC/netflixHub_mount.js"

echo "==> checks"
node --check "$GSZ/$RT" && echo "   netflixHub.js ok"
node --check "$GSZ/$SV" && echo "   server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HM','utf8'),{filename:'$GSZ/$HM'});console.log('   hub_model.ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Netflix tiered codes panel now shows inside the hub (My Purchases)"
