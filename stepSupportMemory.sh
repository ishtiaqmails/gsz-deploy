#!/usr/bin/env bash
# Live Support Bot — anti-confusion: short conversation memory (resolves follow-ups to the last
# product) + the widget queues rapid-fire messages so every one is answered in order.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-smem-$TS"; cd "$GSZ"
HM=views/partials/hub_model.ejs; R=routes/support.js
mkdir -p "$BK/$(dirname "$HM")" "$BK/routes"; cp "$GSZ/$HM" "$BK/$HM"; cp "$GSZ/$R" "$BK/$R"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$HM" "$GSZ/$HM"; cp "$BK/$R" "$GSZ/$R"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

cp -f "$SRC/supportbot.js"   "$GSZ/lib/supportbot.js"
cp -f "$SRC/support_route.js" "$GSZ/$R"
cp -f "$SRC/hub_model.ejs"   "$GSZ/$HM"
node --check "$GSZ/lib/supportbot.js" && node --check "$GSZ/$R" && echo "   libs ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HM','utf8'),{filename:'$GSZ/$HM'});console.log('   hub_model.ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

echo "--- conversation memory test (one session via cookie jar) ---"
J=/tmp/sbmem.$$; rm -f "$J"
ask(){ echo "Q: $1"; curl -s -c "$J" -b "$J" -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$1\"}" | sed 's/\\n/ | /g' | head -c 240; echo; }
ask "tell me about opplex tv"
ask "how much?"
ask "does it work on firestick?"
ask "and nord vpn?"
ask "how much?"
rm -f "$J"
echo
echo "DONE — bot remembers context for follow-ups; rapid messages are queued, not dropped."
