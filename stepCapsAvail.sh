#!/usr/bin/env bash
# Galaxy — product model: real capabilities + per-plan warranty & availability note.
#   caps : Netflix System (nf_enabled) · Login Code (req_otp) · Get Link (has_link/link_url)
#   plan : Warranty (was missing from the UI — drives claims/replacements) + Availability note, both per-plan
#   product-level geo_note is no longer overwritten by the model (existing values preserved)
# + product_plans.avail_note column. Auto-restores adminCatalog.js + the model view on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
echo "== migration: product_plans.avail_note =="
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS avail_note text;"

AC=routes/adminCatalog.js; MODEL=views/admin/product_model.ejs
cp -f "$AC" "$AC.bak.$TS"; cp -f "$MODEL" "$MODEL.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; cp -f "$MODEL.bak.$TS" "$MODEL"; }
trap restore ERR
node "$SRC/patch_caps_avail.js" "$GSZ"
node --check "$AC"
cp -f "$SRC/adm_product_model.ejs" "$MODEL"
node -e "const ejs=require('ejs'),fs=require('fs'),p='$GSZ/views/admin/product_model.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — capabilities fixed (Netflix/Login Code/Get Link) + per-plan Warranty & Availability note."
