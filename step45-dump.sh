#!/usr/bin/env bash
# READ ONLY — diagnose #7 (plans/types data) and #8 (owner-only trials) in the mapping dropdown.
APP=/opt/gsz
PSQL(){ sudo -u postgres psql -d gsz -c "$1" 2>&1 || psql -U gsz_user -d gsz -c "$1" 2>&1; }

echo "========== IPTV products: plans + types =========="
PSQL "SELECT sku, name, plans, types FROM bot_products WHERE delivery_type='iptv' ORDER BY sku;" | head -80

echo; echo "========== any TRIAL / OWNER / TEST named SKUs =========="
PSQL "SELECT sku, name, delivery_type, is_active FROM bot_products WHERE lower(name) LIKE '%trial%' OR lower(name) LIKE '%owner%' OR lower(name) LIKE '%test%' OR lower(name) LIKE '%demo%' ORDER BY sku;"

echo; echo "========== counts =========="
PSQL "SELECT count(*) AS total, count(*) FILTER (WHERE jsonb_array_length(plans)>0) AS with_plans, count(*) FILTER (WHERE jsonb_array_length(types)>0) AS with_types, count(*) FILTER (WHERE delivery_type='iptv') AS iptv FROM bot_products;"

echo; echo "========== which file writes bot_products (sync) =========="
grep -rlE "bot_products" "$APP/routes" "$APP/lib" 2>/dev/null

echo; echo "========== botapi.js (getProducts + sync mapping) =========="
sed -n '1,95p' "$APP/lib/botapi.js" 2>/dev/null

echo "== DONE =="
