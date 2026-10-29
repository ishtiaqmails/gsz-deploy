#!/usr/bin/env bash
# stepSeoFix.sh — fix the SEO QA findings: category + static page meta/canonical/H1/schema,
#   logo/pixel alt, homepage meta length. Patches 6 files. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(views/partials/store_top.ejs server.js routes/category.js views/category.ejs views/resellers.ejs routes/pages.js)
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_seofix.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/server.js" && echo "  server.js ok"
node --check "$GSZ/routes/category.js" && echo "  category.js ok"
node --check "$GSZ/routes/pages.js" && echo "  pages.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['views/partials/store_top.ejs','views/category.ejs','views/resellers.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  '+f+' compiles');});"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "==> re-running SEO QA (should be far cleaner now)"
sleep 2
node "$GSZ/lib/seo_qa.js" 3900 | tail -20
echo
echo "DONE — category + static pages now have meta/canonical/H1/schema; pixel alt added; home meta trimmed."
