#!/usr/bin/env bash
# dumpTrials — facts to build Trials in the Hub (credentials view + Extend 2d + Convert-to-paid).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tAc "$1" 2>&1; }

echo "#### 1. botapi.js — exported functions (generate/extend/convert/renew/trial) ####"
grep -nE "exports\.|^\s*(async )?function |module\.exports|generateTrial|extend|convert|renew|trial" lib/botapi.js 2>/dev/null | grep -iE "exports|function|trial|extend|convert|renew|generate" | head -40

echo "#### 2. trials.js — the customer trials view route + claim + any extend/convert ####"
grep -nE "router\.(get|post)\(['\"][^'\"]+|account/trials|extend|convert|credentials|expires_at" routes/trials.js | head -30

echo "#### 3. trial_servers rows (sku -> name -> duration) ####"
Q "SELECT sku||' | '||name||' | '||COALESCE(duration_label,'')||' | '||COALESCE(duration_hours::text,'') FROM trial_servers WHERE enabled=true ORDER BY name" | head -20

echo "#### 4. trial -> paid product mapping (does a product/plan correspond to a trial sku?) ####"
echo "-- products columns --"
Q "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='products'"
echo "-- product_plans columns --"
Q "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='product_plans'"
echo "-- any products whose bot_sku matches a trial sku? --"
Q "SELECT p.id||' | '||p.name||' | bot_sku='||COALESCE(p.bot_sku,'') FROM products p WHERE p.bot_sku IN (SELECT sku FROM trial_servers) LIMIT 10"
echo "-- bot_products that are trials vs paid (sku, type) --"
Q "SELECT sku||' | '||COALESCE(name,'')||' | '||COALESCE(type,'') FROM bot_products WHERE sku IN (SELECT sku FROM trial_servers) LIMIT 10"

echo "#### 5. a sample claimed trial (credentials format; current user if any) ####"
Q "SELECT 'id='||id||' status='||status||' server='||COALESCE(server_name,trial_type)||' claimed='||COALESCE(claimed_at::text,'')||' expires='||COALESCE(expires_at::text,'')||' credlen='||COALESCE(length(credentials)::text,'0')||' meta='||COALESCE(metadata::text,'{}') FROM trial_claims ORDER BY id DESC LIMIT 4"

echo "#### 6. how renew resolves product for an order (to reuse for convert) ####"
grep -nE "subscription|renewable|slug|options|product_plans|/subscription" routes/account.js routes/checkout.js 2>/dev/null | grep -iE "renewable|subscription|slug|options" | head -15
echo "== dumpTrials done =="
