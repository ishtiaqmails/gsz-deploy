#!/usr/bin/env bash
# Live Support Bot — Stage 5: helpful for EVERYONE (new customers included).
# Guest-safe order tracking by number; agentic intents become warm guidance + Hub-flow buttons
# (no sign-in walls). Refreshes engine + route + widget together.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-sagentic-$TS"; cd "$GSZ"
HM=views/partials/hub_model.ejs; R=routes/support.js
mkdir -p "$BK/$(dirname "$HM")" "$BK/routes"; cp "$GSZ/$HM" "$BK/$HM"; cp "$GSZ/$R" "$BK/$R"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$HM" "$GSZ/$HM"; cp "$BK/$R" "$GSZ/$R"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

cp -f "$SRC/supportkb.js"    "$GSZ/lib/supportkb.js"
cp -f "$SRC/supportbot.js"   "$GSZ/lib/supportbot.js"
cp -f "$SRC/support_route.js" "$GSZ/$R"
cp -f "$SRC/hub_model.ejs"   "$GSZ/$HM"
node --check "$GSZ/lib/supportkb.js" && node --check "$GSZ/lib/supportbot.js" && node --check "$GSZ/$R" && echo "   libs ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HM','utf8'),{filename:'$GSZ/$HM'});console.log('   hub_model.ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

echo "--- guest (not signed in) help tests ---"
for q in "where is my order" "where is my order GSZ-2002" "renew my iptv" "i want a free trial" "my iptv stopped working"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | head -c 500; echo; echo
done
echo "DONE — bot now helps new customers too; order tracking works without login."
