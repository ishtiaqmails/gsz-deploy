#!/usr/bin/env bash
# Galaxy — Product Model rebuild, STEP 1: database fields (additive, idempotent, safe).
# Adds the columns the new Add/Edit Product model needs. No code uses them yet, so nothing changes
# on the live site until the UI + save steps land. Existing data is untouched.
set -Eeuo pipefail
GSZ=/opt/gsz; cd "$GSZ"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
PSQL(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "== products: product-level flags + capabilities =="
PSQL -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE products ADD COLUMN IF NOT EXISTS most_selling  boolean NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS req_otp       boolean NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS has_household boolean NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS has_link      boolean NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS link_url      text;
SQL

echo "== product_plans: structured duration, per-plan note/instructions, custom + required fields =="
PSQL -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS duration_value       numeric(10,2);
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS duration_unit        text;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS product_note         text;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS delivery_instructions text;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS custom_fields        jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS required_fields      jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS version_labels       jsonb NOT NULL DEFAULT '[]'::jsonb;
SQL

echo
echo "== verify: new product columns =="
PSQL -c "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name='products' AND column_name IN ('most_selling','req_otp','has_household','has_link','link_url') ORDER BY column_name;"
echo "== verify: new plan columns =="
PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='product_plans' AND column_name IN ('duration_value','duration_unit','product_note','delivery_instructions','custom_fields','required_fields','version_labels','most_popular') ORDER BY column_name;"
echo "DONE — Step 1: product-model schema added (additive; site unchanged)."
