#!/usr/bin/env bash
# Galaxy — remove the OLD product-page warranty (#pWarranty + data-warranty + its JS); keep the new
# green warranty shield. In-place patch of views/product.ejs. Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
PV=views/product.ejs
cp -f "$PV" "$PV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$PV.bak.$TS" "$PV"; }
trap restore ERR
node "$SRC/patch_rmoldwarr.js" "$GSZ"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$PV','utf8'),{filename:process.cwd()+'/'+'$PV'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — old warranty removed; only the new per-plan warranty shield remains."
