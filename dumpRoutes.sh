#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
echo "===== server.js : route mounts, app.use order, 404 =====" 
grep -nE "app\.(use|get|post)\(|require\(.?\./routes|res\.status\(404|catch.?all|\.render\(" "$GSZ/server.js" | head -120
echo
echo "===== list routes/ =====" 
ls -la "$GSZ/routes" 2>/dev/null || echo "(no routes dir)"
echo
echo "===== views top-level =====" 
ls "$GSZ/views" 2>/dev/null
echo
echo "===== category route: where is /category handled? =====" 
grep -rnE "/category|category/:|categorySlug|renderCategory|'category'|\"category\"" "$GSZ/server.js" "$GSZ/routes" 2>/dev/null | head -40
