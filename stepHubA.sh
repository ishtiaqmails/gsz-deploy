#!/usr/bin/env bash
# Galaxy Hub — Deploy A (frontend): rename Hub, Get Access, Support chooser, Sign In/Out,
# bottom-sheet cart, hamburger reorder. No DB changes.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
NAV=views/partials/app_nav.ejs
CART="$(find . -type f -name cart.css -path '*css*' | grep -v '\.bak' | head -1)"
JS="$(find . -type f -name app.js -path '*js*' | grep -v '\.bak' | head -1)"
HJS="$(grep -rl 'app.js?v=' views --include='*.ejs' | grep -v '\.bak' | head -1)"
HCART="$(grep -rl 'cart.css?v=' views --include='*.ejs' | grep -v '\.bak' | head -1)"
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')
[ -n "$CART" ] && [ -n "$JS" ] || { echo "!! cart.css/app.js not found"; exit 1; }
echo "  cart:$CART  js:$JS  hjs:$HJS  hcart:$HCART"

cp -f "$CT" "$CT.bak.$TS"; cp -f "$NAV" "$NAV.bak.$TS"; cp -f "$CART" "$CART.bak.$TS"; cp -f "$JS" "$JS.bak.$TS"
[ -n "$HJS" ] && cp -f "$HJS" "$HJS.bak.$TS"; [ -n "$HCART" ] && cp -f "$HCART" "$HCART.bak.$TS"
for f in "${FOOTERS[@]}"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; cp -f "$CT.bak.$TS" "$CT"; cp -f "$NAV.bak.$TS" "$NAV"; cp -f "$CART.bak.$TS" "$CART"; cp -f "$JS.bak.$TS" "$JS"; [ -n "$HJS" ] && cp -f "$HJS.bak.$TS" "$HJS"; [ -n "$HCART" ] && cp -f "$HCART.bak.$TS" "$HCART"; for f in "${FOOTERS[@]}"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR

cp -f "$SRC/customer_tools.ejs" "$CT"
cp -f "$SRC/app_nav.ejs" "$NAV"
node "$SRC/patch_appnav.js" "$GSZ"
node "$SRC/patch_cart.js" "$CART"
node "$SRC/patch_appjs.js" "$JS"
node --check "$JS"

if [ -n "$HCART" ]; then cur="$(grep -oE 'cart\.css\?v=[0-9]+' "$HCART" | head -1 | grep -oE '[0-9]+$' || true)"; [ -n "$cur" ] && { new=$((cur+1)); sed -i "s#cart\.css?v=${cur}#cart.css?v=${new}#g" "$HCART"; echo "  bust cart.css v${cur}->v${new}"; }; fi
if [ -n "$HJS" ];   then cur="$(grep -oE 'app\.js\?v=[0-9]+'  "$HJS"  | head -1 | grep -oE '[0-9]+$' || true)"; [ -n "$cur" ] && { new=$((cur+1)); sed -i "s#app\.js?v=${cur}#app.js?v=${new}#g" "$HJS"; echo "  bust app.js v${cur}->v${new}"; }; fi

node -e "const ejs=require('ejs'),fs=require('fs');['$CT','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  hub ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Galaxy Hub A: Hub + Get Access + Support chooser + Sign In/Out + bottom-sheet cart + hamburger (About Us · Track Order · Reseller Panels · FAQ)."
