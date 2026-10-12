#!/usr/bin/env bash
# GSZ (retail VPS) — Hub "Renew IPTV Subscription" flow (customer model), Stage 1b: lookup.
#   - hub_model.ejs: new "Renew IPTV Subscription" entry at the top of the Renew tab ->
#     pick IPTV service -> paste line details (auto-detect username/password) -> shows the
#     line's CURRENT EXPIRY + renewal plans. Verified-WhatsApp gated. No colours changed.
#   - lib/botapi.js: iptvLookup() bridge to gsz-api POST /api/iptv-lookup (read-only, no credits).
#   - routes/account.js: GET /account/tools/iptv/options + POST /account/tools/iptv/lookup.
# Backs up, validates (node --check + ejs compile), restarts gsz, health-checks, auto-restores.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-iptvhub-$TS"
cd "$GSZ"
FILES=(views/partials/hub_model.ejs routes/account.js lib/botapi.js routes/checkout.js)

echo "==> backup -> $BK"
for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

echo "==> replace hub_model.ejs (Renew IPTV Subscription flow)"
cp -f "$SRC/hub_model.ejs" "$GSZ/views/partials/hub_model.ejs"

echo "==> patch lib/botapi.js (iptvLookup bridge)"
node "$SRC/patch_botapi3.js" "$GSZ/lib/botapi.js"

echo "==> patch routes/account.js (iptv options + lookup)"
node "$SRC/patch_iptvhub.js" "$GSZ"

echo "==> patch routes/checkout.js (renew-line pay + fulfill + poll)"
node "$SRC/patch_iptvrenew.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/account.js"
node --check "$GSZ/lib/botapi.js"
node --check "$GSZ/routes/checkout.js"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/views/partials/hub_model.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   hub_model ejs ok');"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Renew IPTV Subscription (lookup) live in the Hub. Pick a service, paste a line, see its expiry. Read-only, no credits."
