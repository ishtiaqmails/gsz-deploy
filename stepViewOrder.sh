#!/usr/bin/env bash
# stepViewOrder.sh — "View order" opens the Galaxy Hub modal at that order (phone/desktop model).
#   views/partials/hub_model.ejs      : window.gszOpenOrder(no)
#   views/partials/checkout_model.ejs : View-order link opens the Hub (fallback /order/<no>)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-vieworder-$TS"; cd "$GSZ"
HB=views/partials/hub_model.ejs; CK=views/partials/checkout_model.ejs
mkdir -p "$BK/views/partials"
cp "$GSZ/$HB" "$BK/$HB"; cp "$GSZ/$CK" "$BK/$CK"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$HB" "$GSZ/$HB"; cp "$BK/$CK" "$GSZ/$CK"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch hub_model.ejs + checkout_model.ejs"
node "$SRC/patch_vieworder.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$HB','$GSZ/$CK'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:f});});console.log('   both views compile');"
grep -q 'window.gszOpenOrder=function' "$GSZ/$HB" && echo "   hub open-order wired"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — View order opens the Galaxy Hub at that order (sign-in for guests; /order fallback). Hard-refresh once."
