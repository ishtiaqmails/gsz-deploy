#!/usr/bin/env bash
# BOT BOX (gsz-api) — add the read-only POST /api/iptv-lookup endpoint (pre-pay IPTV line
# lookup: pasted text/username -> current expiry, no credits). Patches renewalService.js +
# server.js, backs up, validates with node --check, restarts gsz-api, health-checks, and
# auto-restores on any failure. Does NOT touch the reseller bot (galaxy-bot) at all.
set -Eeuo pipefail
API=/opt/gsz-api
PATCHER=${1:-$API/patch_iptvlookup.js}
TS=$(date +%Y%m%d-%H%M%S)
BK="$API/.bak-iptvlookup-$TS"
cd "$API"
FILES=(renewalService.js server.js)

[ -f "$PATCHER" ] || { echo "!! patcher not found at $PATCHER"; exit 1; }

echo "==> backup -> $BK"
mkdir -p "$BK"; for f in "${FILES[@]}"; do cp "$API/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$API/$f"; done; pm2 restart gsz-api >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

echo "==> patch"
node "$PATCHER" "$API"

echo "==> validate"
node --check "$API/renewalService.js"
node --check "$API/server.js"

trap - ERR
pm2 restart gsz-api --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8090/health || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — POST /api/iptv-lookup live on gsz-api (read-only, no credits). Reseller bot untouched."
