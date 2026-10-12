#!/usr/bin/env bash
# Live Support Bot — Stage 3: wire POST /api/support/message to the answer engine.
# Deploys routes/support.js + mounts it in server.js, then live-tests the endpoint.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-sroute-$TS"; cd "$GSZ"
R=routes/support.js; S=server.js
mkdir -p "$BK/routes"; [ -f "$GSZ/$R" ] && cp "$GSZ/$R" "$BK/$R" || true; cp "$GSZ/$S" "$BK/$S"
restore(){ echo "!! FAILED — restoring server.js"; cp "$BK/$S" "$GSZ/$S"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

cp -f "$SRC/support_route.js" "$GSZ/$R"
node "$SRC/patch_mountsupport.js" "$GSZ"
node --check "$GSZ/$R" && echo "   support.js ok"
node --check "$GSZ/$S" && echo "   server.js ok"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

echo "--- live API test ---"
echo "info:"; curl -s http://127.0.0.1:3900/api/support/info; echo
for q in "how much is opplex tv" "recommend a good vpn" "do you have netflix" "i want to talk to a human"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}"; echo; echo
done
echo "DONE — /api/support/message is live. Next: Stage 4 chat widget in the Hub."
