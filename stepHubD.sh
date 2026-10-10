#!/usr/bin/env bash
# Galaxy Hub — Deploy D: Renew on-site (same plans, in-model) + coupon field + admin Renewable flag.
# Migration: products.renewable (boolean, default true). No bot changes; reuses botapi.getSubscription/getPayAccounts
# and the existing /checkout (which already handles b.renew + b.coupon).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
PE=views/admin/product_edit.ejs
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')

cp -f routes/account.js "routes/account.js.bak.$TS"
cp -f routes/adminCatalog.js "routes/adminCatalog.js.bak.$TS"
cp -f "$PE" "$PE.bak.$TS"
cp -f "$CT" "$CT.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "routes/account.js.bak.$TS" routes/account.js; cp -f "routes/adminCatalog.js.bak.$TS" routes/adminCatalog.js; cp -f "$PE.bak.$TS" "$PE"; cp -f "$CT.bak.$TS" "$CT"; }
trap restore ERR

# --- migration: products.renewable (idempotent) ---
node -e 'require("dotenv").config();const {Pool}=require("pg");const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{try{await p.query("ALTER TABLE products ADD COLUMN IF NOT EXISTS renewable boolean DEFAULT true");console.log("  migration: products.renewable ok");}catch(e){console.log("MIGRATION ERR",e.message);process.exit(1);}process.exit(0);})();'

node "$SRC/patch_renewflow.js" "$GSZ"
node "$SRC/patch_prodrenewable.js" "$GSZ"
node "$SRC/patch_prodedit.js" "$GSZ"
cp -f "$SRC/customer_tools.ejs" "$CT"      # adds the coupon field to the Renew checkout

node --check routes/account.js
node --check routes/adminCatalog.js
node -e "const ejs=require('ejs'),fs=require('fs');['$CT','$PE'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/announcements || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Galaxy Hub D: Renew on-site (same plans · coupon field · pays in-model) + admin Renewable flag."
