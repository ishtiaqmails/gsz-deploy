#!/usr/bin/env bash
# Semantic brain — tune product/FAQ arbitration (strong product beats weak cross-product FAQ;
# soft product suggestion for otherwise-fallback queries).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-semtune-$TS"; cd "$GSZ"
mkdir -p "$BK/lib"; cp "$GSZ/lib/supportbot.js" "$BK/lib/"
restore(){ echo "!! FAILED — restoring"; cp "$BK/lib/supportbot.js" "$GSZ/lib/"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/supportbot.js" "$GSZ/lib/supportbot.js"
node --check "$GSZ/lib/supportbot.js" && echo "   supportbot.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "--- re-test natural questions ---"
for q in "will this play on my amazon firestick" "something to watch movies in 4k" "i need to hide my ip and browse safely" "whats good for live sports"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 280; echo; echo
done
echo "DONE"
