#!/usr/bin/env bash
# dumpSeoFix.sh — read-only. How category + static pages render, so we can add SEO meta/H1/schema.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) category route: render + locals (grep) ###"
grep -rnE "category/:|/category|res.render\('category|cat_slug|CATEGORY" "$GSZ"/routes/*.js 2>/dev/null | grep -v node_modules | head -15

echo
echo "### B) category.ejs — heading / H1 / head locals ###"
F="$GSZ/views/category.ejs"; [ -f "$F" ] && { grep -nE "<h1|<h2|class=\"sec-head|title|metaDescription|canonicalUrl|jsonLd|<%- include" "$F" | head -20; echo "-- lines 1-30 --"; win "$F" 1 30; } || echo "no category.ejs"

echo
echo "### C) static page routes: about / faq / resellers (+ their render locals) ###"
grep -rnE "res.render\('(about|faq|resellers)|'/about'|'/faq'|'/resellers'" "$GSZ"/routes/*.js "$GSZ/server.js" 2>/dev/null | grep -v node_modules | head -15

echo
echo "### D) store_top.ejs — the logo <img> (needs alt) ###"
grep -nE "<img" "$GSZ/views/partials/store_top.ejs" 2>/dev/null | head

echo
echo "### E) home route meta description (169 chars -> trim) ###"
grep -nE "metaDescription =|buy premium IPTV" "$GSZ/server.js" 2>/dev/null | head
echo "== END =="
