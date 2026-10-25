#!/usr/bin/env bash
# dumpCheckoutGate.sh v2 — LIVE files only (skip .bak dirs). Bounded, line-numbered.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%5d| %s\n",NR,$0}' "$1"; }

F="$GSZ/routes/checkout.js"
echo "###### LIVE checkout.js : $F ######"
echo "--- SIGNIN_GATE + session.customer refs ---"
grep -nE "SIGNIN_GATE|req\.session\s*&&\s*req\.session\.customer|redirect\('/login|wa_verified|router\.(get|post)\('"'"'/checkout" "$F" | head -30
echo "--- POST /checkout handler: first 40 lines ---"
N=$(grep -n "router.post('/checkout'" "$F" | head -1 | cut -d: -f1)
[ -n "$N" ] && win "$F" "$N" "$((N+40))"

echo
echo "###### what is stored in req.session.customer (login/signup) ######"
grep -rnE "req\.session\.customer\s*=" "$GSZ"/routes/*.js 2>/dev/null | grep -v '\.bak' | head -20

echo
echo "###### bot / whatsapp health helpers available ######"
grep -nE "botapi|\.configured\(\)|wabotOnline|wanotify|bot_status|whatsapp.*health|online" "$GSZ/routes/checkout.js" | head -15
grep -rnE "module.exports|configured|online|health" "$GSZ"/lib/botapi.js 2>/dev/null | head -10
echo "== END v2 =="
