#!/usr/bin/env bash
# Galaxy — Products list rebuild, A1 (backend, additive & safe):
#   + product_downloads.hidden
#   + list route returns image/most_selling/cat_slug + downloads map
#   + /products/bulk-downloads and /products/bulk-visibility
#   + product page hides hidden downloads
# The current list view ignores the extra data until A2 lands. Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
echo "== migration: product_downloads.hidden =="
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "ALTER TABLE product_downloads ADD COLUMN IF NOT EXISTS hidden boolean NOT NULL DEFAULT false;"

AC=routes/adminCatalog.js; PR=routes/products.js
cp -f "$AC" "$AC.bak.$TS"; cp -f "$PR" "$PR.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$PR.bak.$TS" "$PR"; }
trap restore ERR
node "$SRC/patch_prodlist.js" "$GSZ"
node --check "$AC"; node --check "$PR"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — A1: products list backend ready (bulk downloads + visibility + hidden flag)."
