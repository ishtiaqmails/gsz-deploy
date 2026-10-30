#!/usr/bin/env bash
# dumpStage4b.sh — read-only. Integration points for Stage 4: the payments admin route + its
# view (to add a buffer slider), and how admin/API routes mount in server.js (for the owner
# price endpoint). Targeted.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) routes/adminPayments.js (full — small) ###"
wc -l routes/adminPayments.js; win routes/adminPayments.js 1 120

echo
echo "### B) views/admin/payments.ejs — top of the form (where to add a buffer control) ###"
wc -l views/admin/payments.ejs; win views/admin/payments.ejs 1 60

echo
echo "### C) server.js — how admin + api routers mount (require + app.use) ###"
grep -nE "require\('\./routes/(admin|checkout|whatsapp|products)|app.use\(.*(admin|checkout|whatsapp|products|require\('\./routes)" server.js 2>/dev/null | head -40
echo "== END =="
