#!/usr/bin/env bash
# GSZ — IPTV Renewal as its OWN entry, separate from the generic Renew:
#   - home Quick Access band (customer_tools) + mobile Tools sheet (app_nav) get a new
#     "IPTV Renewal" tile that opens the Hub straight into the renew-by-username flow.
#   - hub_model: openIptvRenew() + routing for data-tool/data-act/?tool = "iptvrenew".
# Backs up, validates (ejs compile), restarts, auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-iptventry-$TS"; cd "$GSZ"
FILES=(views/partials/hub_model.ejs views/partials/app_nav.ejs views/partials/customer_tools.ejs)

echo "==> backup -> $BK"
for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

echo "==> copy views"
cp -f "$SRC/hub_model.ejs"      "$GSZ/views/partials/hub_model.ejs"
cp -f "$SRC/app_nav.ejs"        "$GSZ/views/partials/app_nav.ejs"
cp -f "$SRC/customer_tools.ejs" "$GSZ/views/partials/customer_tools.ejs"

echo "==> validate"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['hub_model','app_nav','customer_tools'].forEach(function(n){const p='$GSZ/views/partials/'+n+'.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   '+n+' ejs ok');});"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — 'IPTV Renewal' is now its own Quick Access tile (home + mobile sheet) and opens straight into the renew-by-username flow."
