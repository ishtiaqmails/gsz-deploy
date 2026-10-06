#!/usr/bin/env bash
# READ ONLY — how the mapping dropdown is built + bot_products shape (types/trials/owner).
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing: $1)"; echo "========== END $1 =========="; }
dump "$APP/routes/adminMapping.js"
dump "$APP/views/admin/mapping.ejs"

echo; echo "========== BOT_PRODUCTS schema =========="
sudo -u postgres psql -d gsz -c "\d bot_products" 2>&1 | head -60 \
  || psql -U gsz_user -d gsz -c "\d bot_products" 2>&1 | head -60

echo; echo "========== BOT_PRODUCTS sample (iptv-ish) =========="
SQL="SELECT sku, name, delivery_type, types FROM bot_products ORDER BY sku LIMIT 40;"
sudo -u postgres psql -d gsz -c "$SQL" 2>&1 | head -80 \
  || psql -U gsz_user -d gsz -c "$SQL" 2>&1 | head -80

echo; echo "========== botapi getProducts/getPlans hints =========="
grep -nE "getProducts|getPlans|types|trial|owner|plan_key|plans" "$APP/lib/botapi.js" 2>/dev/null | head -40
echo "== DONE =="
