#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
echo "========== routes/adminGeo.js (FULL) =========="
cat -n "$GSZ/routes/adminGeo.js"
echo
echo "========== views/admin/geo.ejs (FULL) =========="
cat -n "$GSZ/views/admin/geo.ejs"
echo
echo "DONE"
