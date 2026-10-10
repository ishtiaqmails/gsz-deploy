#!/usr/bin/env bash
# dumpHome — find the home-page view + its route + locals, to add Quick Access + tools pop-up on home.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
HV=$(grep -rln "Premium Entertainment" views/ 2>/dev/null | grep -v '\.bak' | head -1)
echo "## HOME VIEW FILE: $HV ##"
echo
echo "## '/' route handler (which view + locals) ##"
grep -rnE "router\.(get)\(['\"]/['\"]|res\.render\(" routes/*.js 2>/dev/null | grep -v '\.bak' | grep -iE "'/'|\"/\"|home|index|store|landing|hero|storefront" | head -20
echo
echo "## does home expose waNumber / session customer? (grep the view) ##"
[ -n "$HV" ] && grep -nE "waNumber|wa_number|session.customer|customer|logo" "$HV" 2>/dev/null | head -12
echo
echo "## HOME VIEW CONTENT ##"
[ -n "$HV" ] && cat -n "$HV"
echo "== dumpHome done =="
