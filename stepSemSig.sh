#!/usr/bin/env bash
# Sidecar reports its content signature; the gsz app skips the push when already current.
# This stops the redundant startup embed that was colliding with live /match calls.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; SEM=/opt/gsz-sem
cp -f "$SRC/sem/index.mjs"  "$SEM/index.mjs"
cp -f "$SRC/supportkb.js"   "$GSZ/lib/supportkb.js"
cp -f "$SRC/semclient.js"   "$GSZ/lib/semclient.js"
node --check "$GSZ/lib/supportkb.js" && node --check "$GSZ/lib/semclient.js" && echo "   libs ok"

echo "=== restart sidecar + populate with signature (out-of-band) ==="
pm2 restart gsz-sem --update-env >/dev/null
for i in $(seq 1 45); do curl -s http://127.0.0.1:3910/health 2>/dev/null | grep -q '"ready":true' && { echo "sidecar ready (${i}s)"; break; }; sleep 1; done
node "$SRC/reindex.js"
echo "sidecar now reports:"; curl -s http://127.0.0.1:3910/health; echo

echo "=== restart gsz (startup will now SKIP the push, since sig matches) ==="
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
sleep 8
echo
echo "=== verify (semantic, settled) ==="
for q in "i need to hide my ip and browse safely" "will this run on firestick" "something to watch movies in 4k" "paraphrase my essay" "edit videos with no watermark" "best iptv for cricket" "turkish dramas with urdu subtitles"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 230; echo; echo
done
echo "DONE"
