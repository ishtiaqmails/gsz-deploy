#!/usr/bin/env bash
# dumpSec3.sh — READ ONLY. The last two surfaces: open-redirect on ?next= and brute-force
# rate-limiting on login / password reset / verification.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== OPEN REDIRECT: how is ?next= validated before redirecting? ====="
grep -nE "next|redirect\(" routes/account.js 2>/dev/null | grep -iE "next" | head -25

echo
echo "===== RATE LIMITING: any limiter on login / reset / verify / order? ====="
grep -rnE "rate.?limit|rateLimit|express-rate|too many|attempts|lockout|slow.?down|advisory|cooldown|interval '[0-9]+ (second|minute)" routes/account.js routes/trials.js server.js lib 2>/dev/null | grep -vE '\.bak' | head -20
echo "  (login brute-force protection would show here; trial uses advisory lock + quota)"

echo
echo "===== login POST handler — attempt throttling / lockout present? ====="
ln=$(grep -nE "router\.post\('/login'" routes/account.js | head -1 | cut -d: -f1); ln=${ln:-120}
sed -n "${ln},$((ln+30))p" routes/account.js
