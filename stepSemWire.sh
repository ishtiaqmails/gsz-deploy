#!/usr/bin/env bash
# Semantic brain — Part 2: wire the sidecar into the bot. The store app pushes its REAL
# catalog+FAQ corpus to gsz-sem and uses semantic matches (product + FAQ) with automatic
# fallback to the keyword engine if the sidecar is slow/down.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-semwire-$TS"; cd "$GSZ"
R=routes/support.js
mkdir -p "$BK/routes" "$BK/lib"
cp "$GSZ/$R" "$BK/$R"; cp "$GSZ/lib/supportkb.js" "$BK/lib/"; cp "$GSZ/lib/supportbot.js" "$BK/lib/"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$R" "$GSZ/$R"; cp "$BK/lib/supportkb.js" "$GSZ/lib/"; cp "$BK/lib/supportbot.js" "$GSZ/lib/"; rm -f "$GSZ/lib/semclient.js"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

cp -f "$SRC/supportkb.js"    "$GSZ/lib/supportkb.js"
cp -f "$SRC/supportbot.js"   "$GSZ/lib/supportbot.js"
cp -f "$SRC/semclient.js"    "$GSZ/lib/semclient.js"
cp -f "$SRC/support_route.js" "$GSZ/$R"
for f in lib/supportkb.js lib/supportbot.js lib/semclient.js "$R"; do node --check "$GSZ/$f"; done
echo "   libs ok"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

echo "--- warming the semantic index with the REAL catalog ---"
curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d '{"message":"hi"}' >/dev/null || true
for i in $(seq 1 25); do
  c=$(curl -s http://127.0.0.1:3910/health | grep -o '"products":[0-9]*' | grep -o '[0-9]*' || echo 0)
  [ "${c:-0}" -gt 5 ] && { echo "sidecar indexed $c products (${i}s)"; break; }
  sleep 1
done

echo
echo "--- natural / paraphrased questions (semantic) ---"
for q in "will this play on my amazon firestick" "how long till i get my stuff after paying" "do you take easypaisa or jazzcash" "something to watch movies in 4k" "i need to hide my ip and browse safely"; do
  echo "Q: $q"
  curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 320; echo; echo
done
echo "DONE — bot now understands meaning (semantic), with keyword fallback. Next: auto-retrain on changes."
