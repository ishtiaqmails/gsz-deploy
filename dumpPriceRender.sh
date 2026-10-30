#!/usr/bin/env bash
# dumpPriceRender.sh — read-only. Exactly how prices render today, so Stage 2 wires geo cleanly.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) app.js — currency engine + picker + paint (1-95) ###"
win "$GSZ/public/js/app.js" 1 95

echo
echo "### B) where prices are emitted (data-pkr / data-usd / pprice) across views ###"
grep -rnE "data-pkr|data-usd|pprice|class=\"price|\.from\b|from_usd|price_pkr" "$GSZ"/views 2>/dev/null | grep -v node_modules | head -25

echo
echo "### C) shellJson + product fields (does a product carry a USD 'from'?) ###"
grep -nE "shellJson|function loadProducts|from:|from_usd|price_usd|price_pkr|MIN\(|min\(" "$GSZ/lib/storefront.js" 2>/dev/null | head -25

echo
echo "### D) server.js global middleware + how shellJson reaches the client ###"
grep -nE "res.locals|shellJson|window\.|app.use\(async|socialLocals|trust proxy" "$GSZ/server.js" 2>/dev/null | head -20

echo
echo "### E) store_top.ejs — currency picker block to retire (auto-geo replaces it) ###"
grep -nE "curFlag|curLabel|gsz_currency|CURRENCIES|currency|data-cur|shellJson|__" "$GSZ/views/partials/store_top.ejs" 2>/dev/null | head -20
echo "== END =="
