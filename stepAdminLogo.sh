#!/usr/bin/env bash
# GSZ — Admin branding: use the real site logo (/static/img/logo.png, the GS×ZD monogram)
# on the admin LOGIN page and in the SIDEBAR, with the gradient-star mark kept as an
# automatic fallback if the image ever fails. View change (login.ejs) + idempotent patch
# (_shell_top.ejs). Auth untouched. Idempotent; backs up; auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-adminlogo-$TS"; TMP=$(mktemp -d)
cd "$GSZ"
PATCHED=(views/admin/login.ejs views/admin/_shell_top.ejs)
echo "==> backup -> $BK"
mkdir -p "$BK"; for f in "${PATCHED[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${PATCHED[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/adm_login.ejs" "$GSZ/views/admin/login.ejs"
cp -f "$SRC/patch_adminlogo.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/login.ejs','views/admin/_shell_top.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — real logo now on the admin login + sidebar (gradient-star kept as fallback)."
