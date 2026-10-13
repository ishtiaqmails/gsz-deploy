#!/usr/bin/env bash
# Self-aware engines: the bot + semantic brain auto-refresh whenever ANY product/plan/price/FAQ
# changes (content-signature detection, 2-min auto-cycle), and re-embed only on real changes.
# Also reloads the corrected, self-aware pilot content (defers plan specifics to live data).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-selfaware-$TS"; cd "$GSZ"
mkdir -p "$BK/lib"; cp "$GSZ/lib/supportkb.js" "$BK/lib/"; cp "$GSZ/lib/semclient.js" "$BK/lib/"
restore(){ echo "!! FAILED — restoring"; cp "$BK/lib/supportkb.js" "$GSZ/lib/"; cp "$BK/lib/semclient.js" "$GSZ/lib/"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/supportkb.js"  "$GSZ/lib/supportkb.js"
cp -f "$SRC/semclient.js"  "$GSZ/lib/semclient.js"
node --check "$GSZ/lib/supportkb.js" && node --check "$GSZ/lib/semclient.js" && echo "   engine libs ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

echo "--- reload corrected self-aware pilot content ---"
node "$SRC/load_content.js" "$SRC/content/pilot.json"

echo
echo "--- verify (answers read your LIVE plans — change a plan and it updates itself) ---"
for q in "how much is netflix" "how many devices on nord vpn" "does canva last how long"; do
  echo "Q: $q"; curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 300; echo; echo
done
echo "DONE — engines are self-aware: edit any plan/price/FAQ in admin and the bot + search data follow automatically within ~2 min (instantly when content is loaded)."
