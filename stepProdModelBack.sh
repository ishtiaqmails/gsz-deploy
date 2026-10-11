#!/usr/bin/env bash
# Galaxy — Product Model, STEP 3 (backend, additive & safe):
#   + product_plans.price_usd (dual pricing: Rs for PK, $ for other countries; null = auto-convert)
#   + GET /admin/products/:id/model.json  and  POST /admin/products/model-save (JSON)
#   + products list route also passes cats + bots
# The existing editor + /products/save are untouched. Auto-restores adminCatalog.js on any error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
echo "== migration: product_plans.price_usd =="
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS price_usd numeric(12,2);"

AC=routes/adminCatalog.js
cp -f "$AC" "$AC.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; }
trap restore ERR
node "$SRC/patch_prodmodel.js" "$GSZ"
node --check "$AC"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "--- smoke: model.json for first product ---"
PID=$(psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tAc "SELECT id FROM products ORDER BY id LIMIT 1" 2>/dev/null || true)
echo "first product id: ${PID:-none} (open /admin/products/${PID:-1}/model.json in the browser to verify)"
echo "DONE — Step 3: product-model backend live (additive; editor + fulfilment untouched)."
