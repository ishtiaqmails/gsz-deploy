#!/usr/bin/env bash
# GSZ — enlarge the payment-method logos (they were 40px, too small). Now 54px with a
# slightly taller tile, in both the Hub pay step (hub_model) and the main checkout
# (checkout_model). No other change. Backs up, validates (ejs compile), restarts, restores on fail.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-paylogos-$TS"; cd "$GSZ"
FILES=(views/partials/hub_model.ejs views/partials/checkout_model.ejs)

echo "==> backup -> $BK"
for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

echo "==> copy views"
cp -f "$SRC/hub_model.ejs"      "$GSZ/views/partials/hub_model.ejs"
cp -f "$SRC/checkout_model.ejs" "$GSZ/views/partials/checkout_model.ejs"

echo "==> validate"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['hub_model','checkout_model'].forEach(function(n){const p='$GSZ/views/partials/'+n+'.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   '+n+' ejs ok');});"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — payment logos enlarged (54px) on the Hub pay step and the main checkout."
