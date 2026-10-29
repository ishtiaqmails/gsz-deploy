#!/usr/bin/env bash
# dumpSeo.sh — read-only inventory of current SEO: routes, sitemaps, meta/canonical, structured data.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### 1) SEO routes (sitemap / robots / indexnow / rss) in server.js + routes ###"
grep -rnEi "sitemap|robots\.txt|/robots|indexnow|rss|\.xml|feed" "$GSZ/server.js" "$GSZ"/routes/*.js 2>/dev/null | grep -v node_modules | grep -viE "sitemapindexnowstub" | head -25

echo
echo "### 2) per-page meta: canonical / description / og on each view ###"
for v in home category product about iptv notfound; do
  f="$GSZ/views/$v.ejs"; [ -f "$f" ] || continue
  echo "-- $v.ejs: $(grep -ciE "canonicalurl|canonical|metadescription|og:title|jsonld|json-ld" "$f") seo hooks | title/meta in route?"
done
grep -rnE "canonicalUrl|metaDescription|ogTags|jsonLd|_SEO_v" "$GSZ"/routes/*.js "$GSZ/server.js" 2>/dev/null | grep -v node_modules | grep -oE "[A-Za-z_]+_SEO_v[0-9]+|canonicalUrl|metaDescription|ogTags|jsonLd" | sort | uniq -c | head

echo
echo "### 3) structured data types already emitted (JSON-LD @type) ###"
grep -rhoE "'@type': ?'[A-Za-z]+'|@type\\\":\\\"[A-Za-z]+" "$GSZ"/routes/*.js "$GSZ/server.js" "$GSZ"/views/*.ejs 2>/dev/null | sort | uniq -c | head -30

echo
echo "### 4) head partial: where title/meta/canonical render ###"
ls "$GSZ"/views/partials/*.ejs 2>/dev/null | head
grep -rlnE "<title>|canonical|og:title|twitter:card|jsonLd|json-ld" "$GSZ"/views/partials/*.ejs 2>/dev/null | head
grep -nE "<title>|canonical|og:|twitter:|application/ld\+json|metaDescription|jsonLd" "$GSZ"/views/partials/store_top.ejs 2>/dev/null | head -20

echo
echo "### 5) robots.txt / sitemap currently served? ###"
for p in /robots.txt /sitemap.xml /sitemap_index.xml; do code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:3900$p" || true); echo "   $p -> HTTP $code"; done
echo "== END =="
