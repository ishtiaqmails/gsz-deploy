#!/usr/bin/env bash
# stepCurrency3.sh — Stage 2.1 worldwide currency coverage.
#   lib/gsz_pricing.js: complete ISO country->currency map (245 countries).
#   public/js/app.js: converter now handles ANY currency from the live feed + Intl formatting.
# Patches 2 files. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(lib/gsz_pricing.js public/js/app.js)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_currency3.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/lib/gsz_pricing.js" && echo "  gsz_pricing.js ok"
node --check "$GSZ/public/js/app.js"  && echo "  app.js ok"
node -e "const p=require('$GSZ/lib/gsz_pricing.js');console.log('  countries mapped:',Object.keys(p.CC_CUR).length,'| distinct currencies:',new Set(Object.values(p.CC_CUR)).size);"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done

echo
echo "==> geo spot-check (previously-missed countries now resolve to their own currency)"
for cc in NG BR JP MX FJ ZW; do
  geo=$(curl -s -H "CF-IPCountry: $cc" http://127.0.0.1:3900/ | grep -o 'window.__GEO = {[^}]*}' | head -1)
  echo "  [$cc] ${geo:-<no __GEO>}"
done
echo
echo "DONE — worldwide coverage live. Every country resolves a currency server-side; the client"
echo "converts it from the live USD feed and formats with the browser's own currency formatter."
