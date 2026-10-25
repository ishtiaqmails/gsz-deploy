#!/usr/bin/env bash
# stepVerifyToggle.sh — Step 3a: one-click admin toggle for the checkout verify requirement.
#   Adds a "Checkout policy" card to /admin/whatsapp (checkbox -> wa_settings.require_wa_verify).
#   Refreshes routes/adminWhatsapp.js + views/admin/whatsapp.ejs. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(routes/adminWhatsapp.js views/admin/whatsapp.ejs)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/adminWhatsapp.js" "$GSZ/routes/adminWhatsapp.js"
cp -f "$SRC/adm_whatsapp.ejs" "$GSZ/views/admin/whatsapp.ejs"
node --check "$GSZ/routes/adminWhatsapp.js" && echo "  adminWhatsapp.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/views/admin/whatsapp.ejs','utf8'),{filename:'$GSZ/views/admin/whatsapp.ejs'});console.log('  whatsapp.ejs compiles');"
grep -q "verify-policy" "$GSZ/routes/adminWhatsapp.js" && echo "  policy route present"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — go to /admin/whatsapp: new 'Checkout policy' card toggles the verify requirement (no SQL needed)."
