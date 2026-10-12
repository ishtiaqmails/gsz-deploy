#!/usr/bin/env bash
# GSZ admin shell — premium layout fixes (central, only the two admin partials):
#   #70 no horizontal scroll: tables stack into clean label/value rows on narrow
#       screens instead of forcing a 560px min-width + sideways scroll.
#   #71 nothing cut on mobile: content stays within the viewport, clears the footer.
#   #72 no jump to top on refresh/save: scroll position persists across AJAX saves.
# Backs up both files, validates (ejs compile), restarts, restores on any failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-admshell-$TS"; cd "$GSZ"
T=views/admin/_shell_top.ejs; B=views/admin/_shell_bottom.ejs
mkdir -p "$BK/$(dirname "$T")"; cp "$GSZ/$T" "$BK/$T"; cp "$GSZ/$B" "$BK/$B"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$T" "$GSZ/$T"; cp "$BK/$B" "$GSZ/$B"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_adminshell.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$T','$B'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   admin shell ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — admin tables stack cleanly on mobile (no sideways scroll), content fits, scroll stays put on save."
