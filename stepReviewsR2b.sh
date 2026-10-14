#!/usr/bin/env bash
# stepReviewsR2b.sh — public shareable review page (/review, /review/<slug>) for manual customers.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-reviewsr2b-$TS"; cd "$GSZ"
SV=server.js
mkdir -p "$BK"; cp "$GSZ/$SV" "$BK/$SV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SV" "$GSZ/$SV"; rm -f "$GSZ/routes/reviewpublic.js" "$GSZ/views/review.ejs"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install review router + view, mount in server.js"
cp "$SRC/reviewpublic.js" "$GSZ/routes/reviewpublic.js"
cp "$SRC/review.ejs" "$GSZ/views/review.ejs"
node "$SRC/patch_reviews_r2b.js" "$GSZ"
node --check "$GSZ/routes/reviewpublic.js" && echo "   reviewpublic.js ok"
node --check "$GSZ/$SV" && echo "   server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/review.ejs','utf8'),{filename:'$GSZ/views/review.ejs'});console.log('   review.ejs compiles');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   /review check:"; curl -s -o /dev/null -w '   /review -> %{http_code}\n' http://127.0.0.1:3900/review || true
echo "DONE — shareable review page live at /review (and /review/<product-slug>)."
