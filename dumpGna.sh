#!/usr/bin/env bash
# dumpGna.sh — read-only. Find where the mobile "Store" category sheet (gna-sheet) is built and
# why it shows only 5 categories (hardcoded list / slice limit) instead of all.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
echo "### A) where 'gna-sheet' / gna / the Store sheet is defined ###"
grep -rlnE "gna-sheet|gna|Store sheet|bottom.?nav|appbar|app-bar" views/ public/js/ 2>/dev/null | grep -viE "\.bak|node_modules" | head
echo
echo "### B) category rendering in the mobile nav (slice/limit/hardcoded list?) ###"
grep -rnE "gna|category/|categories|cats\b|slice\(0|\.slice\(|data-cat|Windows Activation|Entertainment" views/partials/store_top.ejs views/partials/store_bottom.ejs public/js/app.js 2>/dev/null | grep -viE "node_modules" | head -40
echo
echo "### C) any hardcoded category list (5 items) in templates/js ###"
grep -rnE "Entertainment.*IPTV|iptv.*vpns|players.*windows|'entertainment'|\"entertainment\"" views/ public/js/app.js 2>/dev/null | grep -viE "\.bak|node_modules" | head -15
echo "== END =="
