#!/usr/bin/env bash
# stepPdpLibrary.sh — product pages reflect the live library + checkout sign-in gate.
#   - routes/checkout.js: GET /checkout now requires sign-in (covers the product "Buy now" link).
#   - views/product.ejs: IPTV products get a "What's Inside" tab (live counts + browse link).
# In-place, idempotent patch (safe to re-run). Backs up both files; restores on any failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-pdplib-$TS"; cd "$GSZ"

CO=routes/checkout.js; PV=views/product.ejs
for f in "$CO" "$PV"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "$CO" "$PV"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patching"
node "$SRC/patch_pdplibrary.js"

echo "==> syntax checks"
node --check "$GSZ/$CO" && echo "   checkout.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$PV';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   product.ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — checkout sign-in gate + IPTV product pages show the live library"
