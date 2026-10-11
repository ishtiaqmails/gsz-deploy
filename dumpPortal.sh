#!/usr/bin/env bash
# dumpPortal — how portal/Netflix products are listed, so the model's "Portal" product type can map
# a plan to one. READ ONLY — does not touch the accounts portal.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
PSQL(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }
echo "########## tables with portal / nf in the name ##########"
PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%portal%' OR table_name ILIKE 'nf[_]%');" 2>&1
echo "########## how nf_portal_product_id is chosen (adminNetflix.js) ##########"
grep -nE "nf_portal_product_id|portal|products|fetch|http" routes/adminNetflix.js 2>&1 | head -40
echo "########## adm_netflix.ejs — the portal product picker markup ##########"
grep -nE "nf_portal_product_id|portal|option|select" views/admin/netflix.ejs 2>&1 | head -30
echo "== dumpPortal done =="
