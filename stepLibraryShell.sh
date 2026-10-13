#!/usr/bin/env bash
# stepLibraryShell.sh — de-orphan /library + stronger name cleaning + de-market copy.
#   - lib/iptv/clean.js   : symbol-thorough, safe (known-code-only) name cleaner, idempotent.
#   - lib/iptv/pages.js   : library pages now render INSIDE the store shell (same theme/nav/footer),
#                           dark, responsive, factual copy only.
#   - routes/iptv.js      : /library + /library/:server render via the shell; browse.json cleans
#                           names at display time (existing data cleans instantly, no re-pull).
#   - views/library.ejs   : shell wrapper (store_top + body + store_bottom).
#   - product.ejs         : What's Inside copy de-marketed.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-libshell-$TS"; cd "$GSZ"

CL=lib/iptv/clean.js; PG=lib/iptv/pages.js; RT=routes/iptv.js; LV=views/library.ejs; PV=views/product.ejs
for f in "$CL" "$PG" "$RT" "$PV"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
[ -f "$GSZ/$LV" ] && { mkdir -p "$BK/$(dirname "$LV")"; cp "$GSZ/$LV" "$BK/$LV"; }
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "$CL" "$PG" "$RT" "$PV"; do cp "$BK/$f" "$GSZ/$f" 2>/dev/null || true; done; [ -f "$BK/$LV" ] && cp "$BK/$LV" "$GSZ/$LV" || rm -f "$GSZ/$LV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/iptv/clean.js" "$GSZ/$CL"
cp -f "$SRC/iptv/pages.js" "$GSZ/$PG"
cp -f "$SRC/iptv_route.js" "$GSZ/$RT"
cp -f "$SRC/library.ejs"   "$GSZ/$LV"

echo "==> de-market product.ejs What's Inside copy"
node "$SRC/patch_pdplibrary.js"

echo "==> engine migrate (bump version -> background re-pull with folded series + full clean)"
node "$SRC/iptv_migrate.js" || echo "   (migrate non-fatal; display-time fold still applies)"

echo "==> syntax checks"
node --check "$GSZ/$CL" && echo "   clean.js ok"
node --check "$GSZ/$PG" && echo "   pages.js ok"
node --check "$GSZ/$RT" && echo "   iptv.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$LV','$GSZ/$PV'].forEach(p=>ejs.compile(fs.readFileSync(p,'utf8'),{filename:p}));console.log('   ejs ok');"

echo "==> restart gsz + worker"
pm2 restart gsz --update-env >/dev/null
pm2 restart gsz-iptv-worker >/dev/null 2>&1 || true
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — /library now lives in the site shell, names cleaned, copy de-marketed"
