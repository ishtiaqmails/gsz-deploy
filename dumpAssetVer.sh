#!/usr/bin/env bash
# dumpAssetVer.sh — read-only. How static assets are versioned (?v=) so a change can auto-bust
# cache. Find the app.js include, how the version number is produced, and where locals are set.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
echo "### A) every ?v= asset include in views ###"
grep -rnoE "/static/[a-zA-Z0-9_./-]+\?v=[^\"'\\)]*" views/ 2>/dev/null | grep -v node_modules | sort -u | head -40
echo
echo "### B) how the version is produced (hardcoded 41? a variable/helper?) ###"
grep -rnE "v=41|v=<%|assetVer|jsVer|cssVer|ASSET_VER|staticVer|APP_VER|buildVer|\?v='" views/ server.js routes/*.js lib/*.js 2>/dev/null | grep -v node_modules | head -25
echo
echo "### C) the app.js include line(s) exactly ###"
grep -rnE "app\.js" views/ 2>/dev/null | grep -v node_modules | head
echo
echo "### D) server.js — app.locals / res.locals / static mount (where to add a version helper) ###"
grep -nE "app\.locals|res\.locals|express\.static|app\.use\('/static'|app\.set\('view" server.js 2>/dev/null | head -20
echo "== END =="
