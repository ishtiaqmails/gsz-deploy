#!/usr/bin/env bash
# stepBlogButtons.sh — buying-guide/blog buttons: JSON-controllable colours + professional,
# responsive styling (own scoped .cs-btn class so the article link colour no longer leaks in).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-blogbtn-$TS"; cd "$GSZ"
B=lib/csblocks.js; R=lib/csrender.js; C=public/css/content.css; A=views/content_article.ejs; L=views/content_list.ejs
for f in "$B" "$R" "$C" "$A" "$L"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "$B" "$R" "$C" "$A" "$L"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
cp -f "$SRC/csblocks.js"          "$GSZ/$B"
cp -f "$SRC/csrender.js"          "$GSZ/$R"
cp -f "$SRC/content.css"          "$GSZ/$C"
cp -f "$SRC/content_article.ejs"  "$GSZ/$A"
cp -f "$SRC/content_list.ejs"     "$GSZ/$L"
node --check "$GSZ/$B" && echo "   csblocks.js ok"
node --check "$GSZ/$R" && echo "   csrender.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$A','$GSZ/$L'].forEach(p=>ejs.compile(fs.readFileSync(p,'utf8'),{filename:p}));console.log('   ejs ok');"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — guide buttons are colour-controllable from JSON + professional & responsive"
