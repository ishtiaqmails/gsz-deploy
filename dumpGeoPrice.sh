#!/usr/bin/env bash
# dumpGeoPrice.sh — how a geo PAGE prices products, so prices become country-aware
# (a UK/US page must not show the Pakistani Rs price).
set -uo pipefail
GSZ=/opt/gsz; LB="$GSZ/lib"; [ -d "$GSZ/libsrc" ] && LB="$GSZ/libsrc"
echo "========== A) routes/geo.js — what price/currency data it passes to the view =========="
grep -nE "price|currency|cur|usd|pkr|symbol|resolve|geoCur|__GEO|render|location|country" "$GSZ/routes/geo.js" 2>/dev/null | head -40
echo
echo "========== B) views/geo.ejs — how price is DISPLAYED =========="
grep -nE "price|currency|cur|usd|pkr|Rs|symbol|__GEO|paintPrices|pprice|data-" "$GSZ/views/geo.ejs" 2>/dev/null | head -40
echo
echo "========== C) the pricing engine (resolve signature: does it take a country?) =========="
echo "--- gsz_pricing / pricing lib ---"
PF=$(ls "$GSZ"/lib/*pricing*.js "$GSZ"/libsrc/*pricing*.js 2>/dev/null | head -1); echo "FILE: $PF"
grep -nE "module.exports|function |resolve|curFor|country|iso|symbol|usd|pkr|format" "$PF" 2>/dev/null | head -30
echo
echo "========== D) geo_content / seo_meta price hooks (what number they bake into the page) =========="
grep -rnE "price|currency|cur|usd|symbol|resolve|amount|offer" "$LB/geo_content.js" "$LB/seo_meta.js" 2>/dev/null | head -25
echo
echo "DONE"
