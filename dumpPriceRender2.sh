#!/usr/bin/env bash
# dumpPriceRender2.sh — read-only. Final rendering internals for Stage 2 (rates loader, product
# price JS, currency picker markup, shared card helper, __DATA injection).
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) app.js 95-175 (live-rates loader + currency init / DOMReady) ###"
win "$GSZ/public/js/app.js" 95 175

echo
echo "### B) product.ejs 400-455 (client price JS reading data-pkr) ###"
win "$GSZ/views/product.ejs" 400 455

echo
echo "### C) store_top.ejs 78-112 (currency chip + modal to retire) ###"
win "$GSZ/views/partials/store_top.ejs" 78 112

echo
echo "### D) shared card() helper (home/category product card) ###"
grep -rnE "function card\(|var card *=|card *=|cardsFor|window.__DATA|__DATA *=" "$GSZ"/views/*.ejs "$GSZ"/views/partials/*.ejs "$GSZ"/server.js 2>/dev/null | grep -v node_modules | head -15
echo "== END =="
