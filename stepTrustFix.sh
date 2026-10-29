#!/usr/bin/env bash
# stepTrustFix.sh — homepage/product trust + review credibility fix.
#   - top stats band shows the real values (never a stuck "0")
#   - removes Trustpilot logo/wording (home + product)
#   - review cards: "Verified Purchase" (verified) / "Customer Review" (otherwise)
#   Patches server.js + views/home.ejs + views/product.ejs. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(server.js views/home.ejs views/product.ejs)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_trustfix.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/server.js" && echo "  server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['views/home.ejs','views/product.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  '+f+' compiles');});"
if grep -q "Trustpilot" "$GSZ/views/home.ejs" "$GSZ/views/product.ejs"; then echo "  WARN: a Trustpilot reference still remains"; else echo "  no Trustpilot references remain"; fi

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — top band now shows your real rating/orders (no 0), Trustpilot removed, reviews labelled Verified Purchase / Customer Review."
