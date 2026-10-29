#!/usr/bin/env bash
# dumpTrust2.sh — read-only. Exact logic for homepage stats + review block + product trust block.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### home.ejs — stat band + review block (55-160) ###"
win "$GSZ/views/home.ejs" 55 160
echo
echo "### home.ejs — count-up / gradnum JS ###"
grep -nE "gradnum|data-count|countUp|IntersectionObserver|odNum|ratingRaw|deliveredNum|sinceRaw" "$GSZ/views/home.ejs" | head -25
echo
echo "### server.js homeData() + render (160-210) ###"
win "$GSZ/server.js" 160 210
echo
echo "### product.ejs trust/review block (248-320) ###"
win "$GSZ/views/product.ejs" 248 320
echo
echo "### admin/content.ejs stats/numbers fields (1-34) ###"
win "$GSZ/views/admin/content.ejs" 1 34
echo "== END =="
