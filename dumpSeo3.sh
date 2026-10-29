#!/usr/bin/env bash
# dumpSeo3.sh — read-only. Does the content hub emit Article/BlogPosting schema? What do AI bots see?
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) content-hub route: its SEO/jsonLd block (Article/BlogPosting?) ###"
F=$(grep -rlE "cs_posts|CONTENT_SEO" "$GSZ"/routes/*.js 2>/dev/null | grep -v node_modules | head -1)
echo "FILE: $F"
grep -nE "CONTENT_SEO|jsonLd|@type|Article|BlogPosting|FAQPage|BreadcrumbList|metaDescription|canonicalUrl|ogTags|res.render" "$F" 2>/dev/null | head -30

echo
echo "### B) live robots.txt (how AI/search crawlers are handled) ###"
curl -s "http://127.0.0.1:3900/robots.txt" | head -40

echo
echo "### C) is there a site search page (for WebSite SearchAction)? ###"
grep -rnE "router.get\('/search|/search'|q=|searchResults" "$GSZ"/routes/*.js 2>/dev/null | grep -v node_modules | head -5
echo "== END =="
