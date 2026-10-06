#!/usr/bin/env bash
# step90-dump — READ-ONLY. Shows the admin shell nav so I can add a "Trials"
# link cleanly, plus the admin route auth pattern. Changes nothing.
set -euo pipefail
APP=/opt/gsz
echo "========== views/admin/_shell_top.ejs =========="
cat "$APP/views/admin/_shell_top.ejs"
echo
echo "========== admin routers mounted in server.js =========="
grep -nE "require\('./routes/admin" "$APP/server.js" || true
echo
echo "========== auth pattern (adminCatalog head) =========="
sed -n '1,10p' "$APP/routes/adminCatalog.js"
echo
echo "==> step90-dump done (read-only)"
