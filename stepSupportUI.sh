#!/usr/bin/env bash
# Live Support Bot — Stage 4: the chat widget in the Hub Support tab (replaces "Live Chat — Coming soon").
# Also refreshes the engine libs so the latest answer logic (incl. the VPN category fix) is live.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-sui-$TS"; cd "$GSZ"
HM=views/partials/hub_model.ejs
mkdir -p "$BK/$(dirname "$HM")"; cp "$GSZ/$HM" "$BK/$HM"
restore(){ echo "!! FAILED — restoring hub_model.ejs"; cp "$BK/$HM" "$GSZ/$HM"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

# refresh engine libs (latest matching logic)
cp -f "$SRC/supportkb.js"  "$GSZ/lib/supportkb.js"
cp -f "$SRC/supportbot.js" "$GSZ/lib/supportbot.js"
node --check "$GSZ/lib/supportkb.js" && node --check "$GSZ/lib/supportbot.js" && echo "   engine libs ok"

# ship the Hub chat widget
cp -f "$SRC/hub_model.ejs" "$GSZ/$HM"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HM','utf8'),{filename:'$GSZ/$HM'});console.log('   hub_model.ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "--- quick re-check: the earlier VPN bug ---"
curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d '{"message":"recommend a good vpn"}' | head -c 400; echo
echo "DONE — Live Chat is now active in the Hub › Support tab. Open the Hub and try it."
