#!/usr/bin/env bash
# stepSeoQa.sh — deploy the on-demand SEO QA checker and run it once.
#   Re-run anytime with:  node /opt/gsz/lib/seo_qa.js
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
cp -f "$SRC/seo_qa.js" "$GSZ/lib/seo_qa.js"
node --check "$GSZ/lib/seo_qa.js" && echo "  seo_qa.js ok"
echo "==> running SEO QA against the live site"
node "$GSZ/lib/seo_qa.js" 3900
echo
echo "DONE — re-run anytime with:  node /opt/gsz/lib/seo_qa.js"
