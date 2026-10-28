#!/usr/bin/env bash
# stepVersionsToggle.sh — mapping screen: per-plan "Versions" control.
#   On a bot product with versions, admin can pick "Let customer choose" (default) or
#   "Single version — <name>". Single version writes bot_type, which hides the customer
#   chooser and pins delivery to that version. UI-only (reuses existing bot_type).
#   Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
M=views/admin/product_model.ejs
cp -f "$M" "$M.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$M.bak.$TS" "$GSZ/$M"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/adm_product_model.ejs" "$GSZ/$M"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs'),p='$GSZ/$M';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  product_model.ejs compiles');"
grep -q "pmVMode" "$GSZ/$M" && echo "  versions control present"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — on the mapping screen, each bot plan with versions now has a 'Versions' dropdown:"
echo "       'Let customer choose' (default) or 'Single version — <name>' to hide the chooser."
echo "       For Hexa4K: set it to Single version (e.g. Family), Save, and the Family/Adult choice disappears on the site."
