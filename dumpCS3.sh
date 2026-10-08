#!/usr/bin/env bash
# dumpCS3 — what I need to wire Content Studio public routes correctly:
# server.js (route mounts + 404), routes/pages.js (how public pages build shell
# locals for store_top), and lib/storefront.js (shellLocals / loadCats helpers).
GSZ=/opt/gsz; cd "$GSZ"
echo "########## server.js ($(wc -l < server.js) lines) ##########"; cat -n server.js
echo
echo "########## routes/pages.js ($(wc -l < routes/pages.js) lines) ##########"; cat -n routes/pages.js
echo
echo "########## lib/storefront.js ($( [ -f lib/storefront.js ] && wc -l < lib/storefront.js || echo MISSING ) lines) ##########"
[ -f lib/storefront.js ] && cat -n lib/storefront.js
echo
echo "########## shellLocals / loadCats references ##########"
grep -rn "shellLocals\|loadCats\|loadSettings\|shellJson\|socialLinks" lib/*.js routes/pages.js 2>/dev/null | head -30
