#!/usr/bin/env bash
# dumpTrust.sh — read-only. Locate every homepage trust/stat/review/Trustpilot string + its source.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
RG(){ grep -rniE "$1" "$GSZ"/views "$GSZ"/routes "$GSZ"/lib "$GSZ"/server.js 2>/dev/null | grep -vE "/node_modules/|\.bak" | head -"${2:-12}"; }

echo "### 1) TOP stats band strings ###"
RG "average customer rating|orders delivered|trusted digital store|since 2021|customers served" 20
echo
echo "### 2) Trustpilot + review-block strings ###"
RG "trustpilot|1,?284|4\.9 ?/ ?5|verified buyer|verified genuine|based on .* reviews" 20
echo
echo "### 3) where the homepage renders + its data (app.get('/') / homeData / render index) ###"
grep -nE "app.get\('/'|homeData|res.render\('index|render\('home|stats|reviews" "$GSZ/server.js" 2>/dev/null | head -20
echo
echo "### 4) homepage view files present ###"
ls -1 "$GSZ"/views/*.ejs 2>/dev/null | grep -iE "index|home|landing" ; ls -1 "$GSZ"/views/partials/*.ejs 2>/dev/null | grep -iE "stat|trust|review|hero|testimon|home" | head
echo "== END =="
