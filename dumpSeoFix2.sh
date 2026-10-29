#!/usr/bin/env bash
# dumpSeoFix2.sh — read-only. Last anchors for the SEO fix patch.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) category.js — the render('category', {...}) object + what vars exist ###"
win "$GSZ/routes/category.js" 1 30

echo
echo "### B) resellers.ejs — headings + first lines (needs an H1) ###"
F="$GSZ/views/resellers.ejs"; [ -f "$F" ] && { grep -nE "<h1|<h2|store_top|hero" "$F" | head; echo "-- 1-14 --"; win "$F" 1 14; } || echo "no resellers.ejs"

echo
echo "### C) about.ejs / faq.ejs include store_top? (so meta flows through) ###"
grep -nE "store_top|<h1|<h2" "$GSZ/views/about.ejs" "$GSZ/views/faq.ejs" 2>/dev/null | head

echo
echo "### D) store_top.ejs noscript tracking pixel (line ~48, needs alt=\"\") ###"
win "$GSZ/views/partials/store_top.ejs" 46 50
echo "== END =="
