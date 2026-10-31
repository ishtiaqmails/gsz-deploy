#!/usr/bin/env bash
# stepGnaCats.sh — mobile Store sheet now renders ALL categories from live `cats` (was 5 hardcoded),
#   and the store_bottom drawer cap (slice 0,6) is lifted. Patches app_nav.ejs + store_bottom.ejs.
# Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(views/partials/app_nav.ejs views/partials/store_bottom.ejs)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
echo "==> patch"; node "$SRC/patch_gnacats.js" "$GSZ"
echo "==> validate (EJS compile)"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs'),p=require('path');['views/partials/app_nav.ejs','views/partials/store_bottom.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:p.resolve('$GSZ/'+f)});console.log('  '+f+' compiles');});"
grep -q "gna-cat-dyn" "$GSZ/views/partials/app_nav.ejs" && echo "  store sheet is now data-driven"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "==> categories now emitted in the mobile Store sheet:"
curl -s http://127.0.0.1:3900/ | grep -oE 'gna-cat gna-cat-dyn" href="/category/[a-z-]+' | sed 's#.*/category/#   #' | sort -u
echo
echo "DONE — the phone Store bar now lists every category (incl. Windows Activations & Keys) and"
echo "auto-updates when you add or remove categories. The app.js cache-bust from earlier ensures"
echo "visitors get this new markup on their next load."
