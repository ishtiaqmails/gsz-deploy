#!/usr/bin/env bash
# Give /match more headroom (600ms -> 1500ms) so a busy-embedding window never causes fallback.
# First prove the sidecar scores are good (direct /match), then deploy + re-test via the bot.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
echo "=== direct sidecar /match (are the scores good?) ==="
for q in "i need to hide my ip and browse safely" "will this run on firestick" "something to watch movies in 4k"; do
  echo "Q: $q"
  curl -s -X POST http://127.0.0.1:3910/match -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | head -c 320; echo; echo
done
echo "=== deploy higher match timeout ==="
cp -f "$SRC/semclient.js" "$GSZ/lib/semclient.js"
node --check "$GSZ/lib/semclient.js" && echo "   ok"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
# warm the index once, then let it settle
curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d '{"message":"hi"}' >/dev/null || true
sleep 8
echo
echo "=== re-test via the bot (settled) ==="
for q in "i need to hide my ip and browse safely" "will this run on firestick" "something to watch movies in 4k" "best iptv for cricket and football" "paraphrase my essay" "edit videos no watermark"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 240; echo; echo
done
echo "DONE"
