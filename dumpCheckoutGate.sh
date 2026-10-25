#!/usr/bin/env bash
# dumpCheckoutGate.sh v3 — LIVE files only. Bounded, line-numbered. Clean patterns.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%5d| %s\n",NR,$0}' "$1"; }

F="$GSZ/routes/checkout.js"
echo "###### LIVE checkout.js : $F ######"
echo "--- gate / session.customer / verify refs ---"
grep -nE "SIGNIN_GATE|req.session.customer|/login|wa_verified|router.post" "$F" | head -40

echo "--- POST /checkout handler: first 42 lines ---"
N=$(grep -n "router.post('/checkout'" "$F" | head -1 | cut -d: -f1)
echo "handler starts at line: $N"
[ -n "$N" ] && win "$F" "$N" "$((N+42))"

echo
echo "###### what is stored in req.session.customer ######"
grep -rnE "req.session.customer =" "$GSZ"/routes/*.js 2>/dev/null | grep -v ".bak" | head -20

echo
echo "###### bot / whatsapp health helpers ######"
grep -nE "botapi|configured|wanotify" "$F" | head -12
grep -nE "module.exports|configured|online|health" "$GSZ/lib/botapi.js" 2>/dev/null | head -10
echo "== END v3 =="
