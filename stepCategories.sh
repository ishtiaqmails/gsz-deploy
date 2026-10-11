#!/usr/bin/env bash
# Galaxy — Admin rebuild: Categories section in the premium mobile + desktop model.
# Backend routes unchanged (list/save/toggle/delete/reorder) — only the view is replaced:
#   stat cards (Total / Active / Hidden), per-slug icons, drag-reorder table, Add/Edit modal
#   (name + tag), Hide/Show, Delete. Collapses to cards on mobile.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
V=views/admin/categories.ejs
cp -f "$V" "$V.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$V.bak.$TS" "$V"; }
trap restore ERR
cp -f "$SRC/adm_categories.ejs" "$V"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$V','utf8'),{filename:process.cwd()+'/'+'$V'});console.log('  categories ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Admin → Categories rebuilt in the premium mobile + desktop model (/admin/categories)."
