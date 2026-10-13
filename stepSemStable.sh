#!/usr/bin/env bash
# Stop the re-index spiral: requests only QUERY the sidecar now; indexing happens out-of-band
# (startup + 5-min timer + after content loads). Restart cleanly and verify semantic answers.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
cp -f "$SRC/semclient.js"    "$GSZ/lib/semclient.js"
cp -f "$SRC/supportbot.js"   "$GSZ/lib/supportbot.js"
cp -f "$SRC/support_route.js" "$GSZ/routes/support.js"
for f in lib/semclient.js lib/supportbot.js routes/support.js; do node --check "$GSZ/$f"; done; echo "   libs ok"

echo "=== clear the sidecar queue (fresh) ==="
pm2 restart gsz-sem --update-env >/dev/null
for i in $(seq 1 45); do curl -s http://127.0.0.1:3910/health 2>/dev/null | grep -q '"ready":true' && { echo "sidecar ready (${i}s)"; break; }; sleep 1; done

echo "=== populate sidecar out-of-band (one clean embed) ==="
node "$SRC/reindex.js"

echo "=== restart gsz (clears the spiral; fresh KB) ==="
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
sleep 3
echo
echo "=== verify (semantic, settled) ==="
for q in "i need to hide my ip and browse safely" "will this run on firestick" "something to watch movies in 4k" "paraphrase my essay" "edit videos with no watermark" "unblock netflix with a vpn"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 240; echo; echo
done
echo "DONE"
