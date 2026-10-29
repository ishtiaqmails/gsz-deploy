#!/usr/bin/env bash
# dumpSeo2.sh — read-only. Gaps check: auto-indexing, sitemap freshness, performance, product OG image.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) IndexNow — does anything AUTO-submit URLs, or only serve the key? ###"
grep -nE "module.exports|function |submit|ping|getKey" "$GSZ/lib/indexnow.js" 2>/dev/null | head -15
echo "-- callers of indexnow.submit / ping across the app --"
grep -rnE "indexnow\.(submit|ping|notify)|submitUrls|pingGoogle|pingBing|ping.*sitemap" "$GSZ"/routes/*.js "$GSZ"/lib/*.js "$GSZ/server.js" 2>/dev/null | grep -v node_modules | grep -v "lib/indexnow.js" | head

echo
echo "### B) sitemap freshness: lastmod / changefreq / priority present? ###"
grep -nE "lastmod|changefreq|priority|updated_at|<url>" "$GSZ/routes/sitemap.js" 2>/dev/null | head -12

echo
echo "### C) performance: compression / static cache / helmet ###"
grep -nE "compression|gzip|brotli|express.static|maxAge|Cache-Control|helmet|etag" "$GSZ/server.js" 2>/dev/null | head -15

echo
echo "### D) product page OG image = the product's own image? ###"
grep -nE "og:image|PROD.*SEO|ogTags|canonicalUrl|metaDescription|p\.image|product.*image" "$GSZ/routes/"*.js 2>/dev/null | grep -iE "og:image|image|_SEO" | grep -i prod | head
echo "== END =="
