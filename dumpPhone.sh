#!/usr/bin/env bash
# dumpPhone.sh — show the exact current signup/login so I can build the phone-field upgrade
# (auto-detected country code + clearer email/phone login) against real code, not guesses.
set -uo pipefail
GSZ=/opt/gsz
echo "========== A) views/account/signup.ejs (FULL) =========="
cat -n "$GSZ/views/account/signup.ejs" 2>/dev/null || echo "(missing)"
echo
echo "========== B) views/account/login.ejs (FULL) =========="
cat -n "$GSZ/views/account/login.ejs" 2>/dev/null || echo "(missing)"
echo
echo "========== C) lib/phone.js (FULL — countries()/normalize()) =========="
cat -n "$GSZ/lib/phone.js" 2>/dev/null || echo "(missing)"
echo
echo "========== D) routes/account.js — login + signup handlers =========="
grep -nE "router\.(get|post)\('/(login|signup)'|res\.render\('account/(login|signup)|countries:|geoCountry|wa_country|normalize\(|phone\." "$GSZ/routes/account.js" 2>/dev/null || echo "(no matches)"
echo
echo "--- render calls for login/signup (with a little context) ---"
grep -n "account/login\|account/signup" "$GSZ/routes/account.js" 2>/dev/null
echo
echo "========== E) where geoCountry / __GEO is set (to auto-detect the code) =========="
grep -rnE "geoCountry|res\.locals\.geo|__GEO" "$GSZ/server.js" "$GSZ/lib" "$GSZ/routes" 2>/dev/null | grep -v node_modules | head -25
echo
echo "========== F) phone country list shape (first option row in signup) =========="
grep -nE "wa_country|countries\.forEach|<option" "$GSZ/views/account/signup.ejs" 2>/dev/null | head -12
echo
echo "DONE"
