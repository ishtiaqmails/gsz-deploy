#!/usr/bin/env bash
# Mobile polish batch: Customer Tools band (2-col) + Shop-by-category/Reviews/Footer + Cart full-width.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"

CSS="$(find . -type f -name 'app.css'  -path '*css*' | grep -v '\.bak' | head -1)"
CART="$(find . -type f -name 'cart.css' -path '*css*' | grep -v '\.bak' | head -1)"
CT="views/partials/customer_tools.ejs"
HEAD="$(grep -rl 'app.css?v=' views --include='*.ejs' | grep -v '\.bak' | head -1)"
[ -n "$CSS" ]  || { echo "!! app.css not found"; exit 1; }
[ -n "$CART" ] || { echo "!! cart.css not found"; exit 1; }
[ -n "$HEAD" ] || { echo "!! head partial not found"; exit 1; }
echo "  css:$CSS  cart:$CART  head:$HEAD"

cp -f "$CSS" "$CSS.bak.$TS"; cp -f "$CART" "$CART.bak.$TS"; cp -f "$HEAD" "$HEAD.bak.$TS"; cp -f "$CT" "$CT.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$CSS.bak.$TS" "$CSS"; cp -f "$CART.bak.$TS" "$CART"; cp -f "$HEAD.bak.$TS" "$HEAD"; cp -f "$CT.bak.$TS" "$CT"; }
trap restore ERR

cp -f "$SRC/customer_tools.ejs" "$CT"
node "$SRC/patch_mobile.js" "$CSS"
node "$SRC/patch_cart.js" "$CART"

# cache-bust both stylesheets so phones fetch the new CSS
for name in app cart; do
  cur="$(grep -oE "${name}\.css\?v=[0-9]+" "$HEAD" | head -1 | grep -oE '[0-9]+$' || true)"
  if [ -n "$cur" ]; then new=$((cur+1)); sed -i "s#${name}\.css?v=${cur}#${name}.css?v=${new}#g" "$HEAD"; echo "  cache-bust: ${name}.css v${cur} -> v${new}"; fi
done

node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$CT','utf8'),{filename:process.cwd()+'/$CT'});console.log('  customer_tools ejs ok');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — mobile polish: Tools band 2-col · category labels fit · reviews carousel · footer 2-col · cart full-width."
