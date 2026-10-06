#!/usr/bin/env bash
# READ ONLY — exact drawer rules in app.css (lines 258-300).
APP=/opt/gsz
echo "========== app.css lines 258-300 =========="
sed -n '258,300p' "$APP/public/css/app.css" 2>/dev/null | cat -n
echo "== DONE =="
