#!/usr/bin/env bash
# dumpWaitlist.sh — read-only. The out-of-stock waitlist: what the /api/waitlist handler stores,
# how the admin dashboard counts "waiting customers", and whether any page lists the details.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) /api/waitlist handler in checkout.js (what it stores) ###"
L=$(grep -n "/api/waitlist" routes/checkout.js | head -1 | cut -d: -f1 || true)
echo "  (handler near line ${L:-?})"
[ -n "${L:-}" ] && win routes/checkout.js $((L-2)) $((L+40))

echo
echo "### B) waitlist references across the app (table name, inserts, counts, any list page) ###"
grep -rnE "waitlist|wait_list|waiting|notify.?me|back.?in.?stock|restock" routes/*.js views/admin/*.ejs lib/*.js 2>/dev/null | grep -viE "node_modules|\.bak" | head -30

echo
echo "### C) admin dashboard route — how the 'waiting' metric is computed ###"
grep -nE "waitlist|waiting|render\('admin/dashboard'|metrics|m\.|dashboard" routes/admin.js 2>/dev/null | head -25

echo
echo "### D) dashboard.ejs — the 'waiting customers' widget ###"
grep -nE "wait|Waiting|out.of.stock|stock" views/admin/dashboard.ejs 2>/dev/null | head -15
echo "== END =="
