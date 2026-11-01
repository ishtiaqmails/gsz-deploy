#!/usr/bin/env bash
# dumpApplyRules.sh — READ ONLY, small. Shows how the live engine consumes geo_product_rules.
set -uo pipefail
GSZ=/opt/gsz
echo "===== routes/geo.js : applyGeoRules (70 lines from its definition) ====="
ln=$(grep -nE "applyGeoRules" "$GSZ/routes/geo.js" | grep -E "function|=>|= async|= function" | head -1 | cut -d: -f1)
[ -z "$ln" ] && ln=$(grep -nE "applyGeoRules" "$GSZ/routes/geo.js" | head -1 | cut -d: -f1)
sed -n "${ln},$((ln+70))p" "$GSZ/routes/geo.js"
echo
echo "===== routes/geo.js : all rule/price references ====="
grep -nE "geo_product_rules|regional_price|currency_override|special_notice|availability|recommended|featured|enabled|purchase_url_override|cta_override" "$GSZ/routes/geo.js" | head -40
echo
echo "===== lib/geo_content.js : rule/price references ====="
grep -nE "geo_product_rules|regional_price|currency_override|special_notice|availability|recommended|featured" "$GSZ/lib/geo_content.js" 2>/dev/null | head -30 || echo "  (none)"
