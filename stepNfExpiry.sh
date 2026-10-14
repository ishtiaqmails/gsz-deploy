#!/usr/bin/env bash
# stepNfExpiry.sh — show each Netflix code's own expiry on the customer panel.
#   hub_model.ejs: per-type validity (codes ~15 min, reset ~60) -> "Expires 5:57 PM (~12 min)",
#                  or dim + red "Expired at 5:42 PM — tap Refresh for a new one".
#   netflixHub.js: include each code's type so the right window is used.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-nfexp-$TS"; cd "$GSZ"
HM=views/partials/hub_model.ejs; RT=routes/netflixHub.js
mkdir -p "$BK/views/partials" "$BK/routes"
cp "$GSZ/$HM" "$BK/$HM"; cp "$GSZ/$RT" "$BK/$RT"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$HM" "$GSZ/$HM"; cp "$BK/$RT" "$GSZ/$RT"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/hub_model.ejs" "$GSZ/$HM"
cp -f "$SRC/netflixHub.js" "$GSZ/$RT"

echo "==> checks"
node --check "$GSZ/$RT" && echo "   netflixHub.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HM','utf8'),{filename:'$GSZ/$HM'});console.log('   hub_model.ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — each code now shows its own expiry on the hub panel"
