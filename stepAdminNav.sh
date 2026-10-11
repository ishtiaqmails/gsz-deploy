#!/usr/bin/env bash
# GSZ — Admin: reorganize the sidebar into clean categories, drop the duplicate
# "WhatsApp bot" link (/admin/whatsapp replaces it), and redesign the mobile footer
# bar to Home / Orders / Reports / Products / Menu. Nav links only — every route stays.
# Idempotent; backs up both shell files, validates, auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-adminnav-$TS"; TMP=$(mktemp -d)
cd "$GSZ"
FILES=(views/admin/_shell_top.ejs views/admin/_shell_bottom.ejs)
echo "==> backup -> $BK"
mkdir -p "$BK/views/admin"; for f in "${FILES[@]}"; do cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/patch_adminnav.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/_shell_top.ejs','views/admin/_shell_bottom.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — admin nav reorganized (8 groups, WhatsApp bot removed) + footer redesigned."
