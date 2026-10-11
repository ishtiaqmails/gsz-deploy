#!/usr/bin/env bash
# Galaxy — Product model: mobile polish + manual $ price + Portal product type.
#   view : fixed mobile layout (no clipped fields), $ price is manual (no auto-convert), labeled/
#          stacked limited-time dates, type segment wraps, + 🌐 Portal type with portal-product picker
#   back : adminNetflix exposes read-only /netflix/portal-products.json; adminCatalog model.json +
#          model-save persist nf_portal_product_id for portal plans
# Auto-restores all three files on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/adminCatalog.js; NF=routes/adminNetflix.js; MODEL=views/admin/product_model.ejs
for f in "$AC" "$NF" "$MODEL"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "$AC" "$NF" "$MODEL"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR
node "$SRC/patch_portal.js" "$GSZ"
node --check "$AC"; node --check "$NF"
cp -f "$SRC/adm_product_model.ejs" "$MODEL"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/product_model.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — model mobile-fixed + manual \$ price + Portal type live."
