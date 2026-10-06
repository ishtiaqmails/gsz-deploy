#!/usr/bin/env bash
# READ ONLY — product card CSS (.pcard and children) for the name-background change.
APP=/opt/gsz
echo "========== app.css .pcard block (lines 183-235) =========="
sed -n '183,235p' "$APP/public/css/app.css" 2>/dev/null | cat -n
echo "== DONE =="
