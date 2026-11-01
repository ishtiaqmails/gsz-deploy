#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
echo "========== routes/geo.js (FULL) =========="
cat -n "$GSZ/routes/geo.js"
echo
echo "========== views/geo.ejs (FULL) =========="
cat -n "$GSZ/views/geo.ejs"
echo
echo "========== lib/geo_content.js — the price() wrapper + how _price lands on products =========="
grep -nE "function price|_price|price\(|catalog|resolve|\.map\(|products" "$GSZ/lib/geo_content.js" 2>/dev/null | head -30
echo "DONE"
