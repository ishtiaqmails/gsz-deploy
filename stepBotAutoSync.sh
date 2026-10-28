#!/usr/bin/env bash
# stepBotAutoSync.sh — automatic bot-catalogue sync (on boot + every 10 min).
#   Deploys lib/botsync_auto.js and wires it into server.js. The manual
#   /admin/bot/sync button is untouched. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
SV=server.js
cp -f "$SV" "$SV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$SV.bak.$TS" "$GSZ/$SV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> deploy auto-sync module + patch server.js"
cp -f "$SRC/botsync_auto.js" "$GSZ/lib/botsync_auto.js"
node --check "$GSZ/lib/botsync_auto.js" && echo "  botsync_auto.js ok"
node "$SRC/patch_botautosync.js" "$GSZ"
node --check "$GSZ/$SV" && echo "  server.js ok"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done

echo "==> waiting for the first auto-sync to run (startup sync fires ~8s after boot)..."
sleep 13
echo "  recent botsync log:"
pm2 logs gsz --nostream --lines 200 2>/dev/null | grep "\[botsync\]" | tail -3 || echo "  (no log line captured yet — it runs within ~8s and then every 10 min)"
echo "DONE — bot products now sync automatically on boot and every 10 minutes. New products appear within ~10 min (or instantly via the Sync button on the mapping page)."
