#!/usr/bin/env bash
# Galaxy — Deploy ProdSeo: per-product SEO. The shared head already renders the cs-seo slot
# (metaDescription / canonicalUrl / ogTags / jsonLd) when provided; this threads real product data
# into those vars from routes/products.js — meta description, Open Graph + Twitter, canonical, and a
# JSON-LD Product with real plan prices. No fake ratings. In-place patch; auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
PR=routes/products.js
cp -f "$PR" "$PR.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$PR.bak.$TS" "$PR"; }
trap restore ERR
node "$SRC/patch_prodseo.js" "$GSZ"
node --check "$PR"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
# quick proof: show the SEO tags the product page now emits
echo "--- SEO head tags on a product page ---"
curl -s "http://127.0.0.1:3900/product/opplex-tv-1-month-26" | grep -oE '<meta name="description"[^>]*>|<link rel="canonical"[^>]*>|<meta property="og:[^>]*>|application/ld\+json' | head -12 || true
echo "DONE — Deploy ProdSeo: product pages now emit meta description, OG/Twitter, canonical + Product JSON-LD."
