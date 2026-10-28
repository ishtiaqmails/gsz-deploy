#!/usr/bin/env bash
# stepTrialGate.sh — fix trials hidden for id-only bot products (e.g. Hexa4K, id=155).
#   The bot trial-gate keyed on p.sku (null for id-only products); now resolves
#   sku -> code -> id like lib/botsync.skuOf. In-place patch; idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
TR=routes/trials.js
cp -f "$TR" "$TR.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$TR.bak.$TS" "$GSZ/$TR"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

node "$SRC/patch_trialgate.js" "$GSZ"
node --check "$GSZ/$TR" && echo "  trials.js ok"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Hexa4K (and any id-only product) now shows its trial in the Get Trial model when enabled."
