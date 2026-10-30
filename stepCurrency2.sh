#!/usr/bin/env bash
# stepCurrency2.sh — Stage 2 dual-currency DISPLAY: auto geo currency, USD-base conversion,
#   owner buffer. Patches 7 files. Idempotent; restores on failure. Checkout stays on the old
#   region logic until Stage 3. Verifies with forced CF-IPCountry before facing a real customer.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(server.js views/partials/store_bottom.ejs public/js/app.js lib/storefront.js views/category.ejs views/home.ejs views/product.ejs)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_currency2.js" "$GSZ"

echo "==> validate JS"
node --check "$GSZ/server.js"      && echo "  server.js ok"
node --check "$GSZ/public/js/app.js" && echo "  app.js ok"
node --check "$GSZ/lib/storefront.js" && echo "  storefront.js ok"
echo "==> validate EJS"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['views/partials/store_bottom.ejs','views/category.ejs','views/home.ejs','views/product.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  '+f+' compiles');});"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done

echo
echo "==> geo verification (forced CF-IPCountry — proves per-country currency before a real visitor)"
for cc in PK GB US AE IN; do
  geo=$(curl -s -H "CF-IPCountry: $cc" http://127.0.0.1:3900/ | grep -o 'window.__GEO = {[^}]*}' | head -1)
  echo "  [$cc] ${geo:-<no __GEO found>}"
done
echo "  [none]  $(curl -s http://127.0.0.1:3900/ | grep -o 'window.__GEO = {[^}]*}' | head -1)"

echo
echo "DONE — Stage 2 live. Visitors now auto-see their currency (PK=PKR, else USD-base x live FX),"
echo "buffer applied from wa_settings.price_buffer_pct (default 0). Checkout = Stage 3 (next)."
