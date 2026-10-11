#!/usr/bin/env bash
# GSZ — Admin polish (batch 1): remove AI-sounding helper text from Categories and
# Inventory (both current in the repo). Categories loses the "drag the handle…" line;
# Inventory's empty-state, bulk-add note and ledger label are tightened. View-only.
# Idempotent; backs up, validates, auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-polish1-$TS"
cd "$GSZ"
FILES=(views/admin/categories.ejs views/admin/inventory.ejs)
echo "==> backup -> $BK"
mkdir -p "$BK/views/admin"; for f in "${FILES[@]}"; do cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/adm_categories.ejs" "$GSZ/views/admin/categories.ejs"
cp -f "$SRC/adm_inventory.ejs" "$GSZ/views/admin/inventory.ejs"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/categories.ejs','views/admin/inventory.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — polish batch 1 (Categories + Inventory text cleaned)."
