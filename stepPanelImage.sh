#!/usr/bin/env bash
# stepPanelImage.sh — per-panel image UPLOAD for reseller panels (replaces the URL field).
#   Redeploys routes/adminResellers.js (multer upload) + views/admin/resellers.ejs (upload + preview + remove).
#   Uses the existing reseller_panels.image_url column (stores /static/img/<file>). Idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-panelimg-$TS"; cd "$GSZ"
AR=routes/adminResellers.js; AV=views/admin/resellers.ejs
mkdir -p "$BK/routes" "$BK/views/admin"
cp "$GSZ/$AR" "$BK/$AR"; cp "$GSZ/$AV" "$BK/$AV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AR" "$GSZ/$AR"; cp "$BK/$AV" "$GSZ/$AV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> deploy updated router + admin view"
cp -f "$SRC/adminResellers.js"   "$GSZ/$AR"
cp -f "$SRC/admin_resellers.ejs" "$GSZ/$AV"

echo "==> validate"
node --check "$GSZ/$AR" && echo "   adminResellers.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$AV','utf8'),{filename:'$GSZ/$AV'});console.log('   admin view compiles');"
node -e "require('$GSZ/node_modules/multer');console.log('   multer present');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done
curl -s -o /dev/null -w '   /resellers -> %{http_code}\n' http://127.0.0.1:3900/resellers || true
curl -s -o /dev/null -w '   /admin/resellers -> %{http_code} (302=login redirect is expected)\n' http://127.0.0.1:3900/admin/resellers || true
echo "DONE — Each panel now has an image UPLOAD (recommended 1200×600) in Admin → Reseller Panels, with preview + remove."
