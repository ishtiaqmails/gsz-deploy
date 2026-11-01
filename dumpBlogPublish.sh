#!/usr/bin/env bash
# dumpBlogPublish.sh — READ ONLY. The exact publish/update hook point + indexnow ping signature
# + whether blog pages already emit structured data. Small output.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== csAdmin.js : where a post is saved / published (hook point) ====="
grep -nE "router\.(get|post|put)|status|published|publish|scheduled|indexnow|UPDATE cs_posts|INSERT INTO cs_posts" routes/csAdmin.js 2>/dev/null | head -40

echo
echo "===== lib/indexnow.js : full (ping signature + base) ====="
sed -n '1,80p' lib/indexnow.js

echo
echo "===== content.js : does a blog page emit JSON-LD / canonical / og? ====="
grep -nE "ld\+json|application/ld|@type|canonical|og:|twitter:|res.render|TYPE_PREFIX|cs_posts|status" routes/content.js 2>/dev/null | head -30

echo
echo "===== which view renders a post, and does it have structured data? ====="
pv=$(grep -rilE "cs_post|article|blog" views 2>/dev/null | head -4); echo "  candidate views: $pv"
for f in $pv; do echo "  -- $f: $(grep -cE "ld\+json|@type|canonical|og:" "$f") seo-tags"; done

echo
echo "===== base URL env + indexnow_auto schedule ====="
grep -nE "SITE_DOMAIN|SITE_URL|baseUrl|PUBLIC_URL" server.js lib/indexnow_auto.js 2>/dev/null | head -10
grep -nE "boot|daily|setInterval|setTimeout|schedule" lib/indexnow_auto.js 2>/dev/null | head -8
