#!/usr/bin/env bash
# Galaxy — Deploy ProdPopular: "Most Popular" plan flag, end to end.
#   DB:    product_plans.popular (boolean)
#   admin: ★ toggle per plan in the product editor (one popular plan per product, label-keyed)
#   save:  adminCatalog.js sets popular by label after the plan upsert
#   page:  routes/products.js threads popular -> product.ejs renders the ribbon + glow
# Idempotent; auto-restores every touched file on any error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"

# --- 1) migration ---
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
echo "== migration: product_plans.popular =="
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS popular boolean NOT NULL DEFAULT false;"

# --- 2) backups + restore trap ---
AC=routes/adminCatalog.js; PR=routes/products.js; PV=views/product.ejs; PE=views/admin/product_edit.ejs
for f in "$AC" "$PR" "$PV" "$PE"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "$AC" "$PR" "$PV" "$PE"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR

# --- 3) patches (adminCatalog + products.js + product.ejs) ---
node "$SRC/patch_prodpopular.js" "$GSZ"

# --- 4) product editor view (direct copy from libsrc) ---
cp -f "$SRC/adm_product_edit.ejs" "$PE"

# --- 5) validate ---
node --check "$AC"
node --check "$PR"
node -e "const ejs=require('ejs'),fs=require('fs');['$PV','$PE'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});console.log('  ejs ok:',f);});"
trap - ERR

# --- 6) restart + health ---
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy ProdPopular: mark any plan ★ Most Popular in the editor; ribbon + glow on the page."
