#!/usr/bin/env bash
# #80 — Coupon product-scoping (specific / multiple / all products).
#   MIGRATION: coupon_products link table (idempotent, additive)
#   PATCHED:   lib/coupon.js (scope-aware validate), routes/adminCoupons.js (load/save scope),
#              routes/checkout.js (pass product ids to validate at all 3 sites)
#   VIEW:      views/admin/coupons.ejs (product picker + scope column)
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-couponscope-$TS"; cd "$GSZ"
L=lib/coupon.js; A=routes/adminCoupons.js; C=routes/checkout.js; V=views/admin/coupons.ejs
for f in "$L" "$A" "$C" "$V"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring code (coupon_products table is additive, left in place)"; for f in "$L" "$A" "$C" "$V"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> migration"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const fs=require('fs');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{await p.query(fs.readFileSync('$SRC/sql_coupon_products.sql','utf8'));console.log('   coupon_products ok');await p.end();})().catch(function(e){console.error('MIGRATION ERR',e.message);process.exit(1);});"

echo "==> patch + view"
node "$SRC/patch_couponlib.js" "$GSZ"
node "$SRC/patch_couponadmin.js" "$GSZ"
node "$SRC/patch_couponscope_checkout.js" "$GSZ"
cp -f "$SRC/adm_coupons.ejs" "$GSZ/$V"

echo "==> validate"
node --check "$GSZ/$L" && echo "   coupon.js ok"
node --check "$GSZ/$A" && echo "   adminCoupons.js ok"
node --check "$GSZ/$C" && echo "   checkout.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$V','utf8'),{filename:'$GSZ/$V'});console.log('   coupons.ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — coupons can now target specific / multiple / all products; enforced at preview, checkout and cart."
