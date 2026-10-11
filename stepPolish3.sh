#!/usr/bin/env bash
# GSZ — Admin polish (batch 3): fix the misleading "SMTP" wording in Marketing (the site
# sends via Brevo), and trim AI-sounding text in Labels, Order detail and Products.
# Skip-on-miss patcher (never aborts on a changed anchor). Idempotent; backs up, validates
# the touched EJS + the marketing route, auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-polish3-$TS"; TMP=$(mktemp -d)
cd "$GSZ"
FILES=(views/admin/marketing.ejs routes/marketing.js views/admin/labels.ejs views/admin/order_detail.ejs views/admin/products.ejs)
echo "==> backup -> $BK"
for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/patch_polish3.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/marketing.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/marketing.ejs','views/admin/labels.ejs','views/admin/order_detail.ejs','views/admin/products.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — polish batch 3 (Marketing wording + Labels/Order detail/Products text)."
