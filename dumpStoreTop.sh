#!/usr/bin/env bash
# dumpStoreTop — the shared <head> (to add per-page SEO meta/OG/canonical) + how the product route
# passes title/settings, so a product `seo` object can be threaded in without guessing.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
f=views/partials/store_top.ejs
echo "########## store_top.ejs — head region (first 70 lines) ##########"
sed -n '1,70p' "$f"
echo
echo "########## existing meta/title/og/canonical in store_top ##########"
grep -nE "<title|meta name|meta property|og:|canonical|description|locals|typeof" "$f" | head -40
echo
echo "########## product route render context (title/settings/seo) ##########"
grep -nE "res.render\('product'|title:|siteName|settings|logoFile|p: prow|p\.image|short_desc|long_desc" routes/products.js | head -30
echo "== dumpStoreTop done =="
