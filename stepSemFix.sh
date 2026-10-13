#!/usr/bin/env bash
# Recover the semantic sidecar after it dropped during the big re-index.
# Shows why it stopped, restarts it, waits for the model, then re-embeds the full corpus.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
echo "=== gsz-sem status + recent logs (why it stopped) ==="
pm2 describe gsz-sem 2>/dev/null | grep -E "status|restarts|memory|uptime|exit code|script path" || true
echo "--- last log lines ---"
pm2 logs gsz-sem --lines 20 --nostream 2>/dev/null | tail -25 || true
echo
echo "=== restart gsz-sem ==="
pm2 restart gsz-sem --update-env >/dev/null 2>&1 || pm2 start "$GSZ"/../gsz-sem/index.mjs --name gsz-sem --update-env 2>/dev/null || (cd /opt/gsz-sem && pm2 start index.mjs --name gsz-sem)
echo "waiting for the model to load…"
for i in $(seq 1 45); do
  r=$(curl -s http://127.0.0.1:3910/health 2>/dev/null || true)
  echo "$r" | grep -q '"ready":true' && { echo "ready (${i}s)"; break; }
  sleep 1
done
echo
echo "=== re-embed the full catalog + FAQs ==="
node "$SRC/reindex.js"
echo
echo "=== verify semantic answers ==="
for q in "something to watch movies in 4k" "i need to hide my ip and browse safely" "will this run on firestick" "best iptv for cricket"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 260; echo; echo
done
echo "DONE"
