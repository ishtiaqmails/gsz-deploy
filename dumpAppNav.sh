#!/usr/bin/env bash
# dumpAppNav.sh — read-only. The mobile Store sheet partial (app_nav.ejs) — how it lists
# categories and where the 5-item limit is.
set -uo pipefail
GSZ=/opt/gsz; F="$GSZ/views/partials/app_nav.ejs"
echo "### app_nav.ejs size ###"; wc -l "$F"
echo "### category rendering lines ###"
grep -nE "category/|cats|slice|forEach|gna-sheet|Entertainment|Windows" "$F" 2>/dev/null | head -30
echo
echo "### full file ###"
awk '{printf "%4d| %s\n",NR,$0}' "$F"
echo "== END =="
