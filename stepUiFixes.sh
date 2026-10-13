#!/usr/bin/env bash
# stepUiFixes.sh — library filter rows wrap (nothing cut on any device) +
#   signed-out Buy Now opens the sign-in prompt INSIDE the checkout modal (sheet on
#   phones, pop-up on desktop) instead of jumping to a separate /login page.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-uifixes-$TS"; cd "$GSZ"
PG=lib/iptv/pages.js; CM=views/partials/checkout_model.ejs
for f in "$PG" "$CM"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "$PG" "$CM"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
cp -f "$SRC/iptv/pages.js"      "$GSZ/$PG"
cp -f "$SRC/checkout_model.ejs" "$GSZ/$CM"
node --check "$GSZ/$PG" && echo "   pages.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$CM','utf8'),{filename:'$GSZ/$CM'});console.log('   checkout_model.ejs ok');"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — library filters wrap (nothing cut) + signed-out Buy Now uses the modal sign-in"
