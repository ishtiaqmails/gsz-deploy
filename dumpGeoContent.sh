#!/usr/bin/env bash
# dumpGeoContent.sh — READ ONLY, focused. The two helpers a pick-page builder reuses:
#   geo_admin.contentDeps + buildCtx (how products + context feed the content engine),
#   and geo_content.assemble (what content_data it returns).
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
echo "===== geo_admin.js : contentDeps() + buildCtx() ====="
ln=$(grep -nE "function contentDeps|contentDeps\s*=" lib/geo_admin.js | head -1 | cut -d: -f1); ln=${ln:-1}
sed -n "${ln},$((ln+40))p" lib/geo_admin.js
echo
echo "===== geo_content.js : assemble() (full) ====="
ln=$(grep -nE "assemble\s*[:=]|function assemble|async assemble" lib/geo_content.js | head -1 | cut -d: -f1); ln=${ln:-1}
sed -n "${ln},$((ln+95))p" lib/geo_content.js
echo
echo "===== geo_content.js : what it returns + module.exports ====="
grep -nE "return\s*\{|module.exports" lib/geo_content.js | head -12
