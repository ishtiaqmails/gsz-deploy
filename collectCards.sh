#!/usr/bin/env bash
# Snapshot storefront product-card + suggestion + IPTV-count source for review.
# No secrets copied (.env is never touched).
set -Eeuo pipefail
GSZ=/opt/gsz; DST=/opt/gsz-deploy/_review
mkdir -p "$DST"

# 1) directory listings so we learn the real filenames
for d in routes lib views views/partials; do
  [ -d "$GSZ/$d" ] && ls -1 "$GSZ/$d" > "$DST/_ls_$(echo "$d" | tr '/' '_').txt" 2>/dev/null || true
done

# 2) copy likely card / suggestion / count sources if they exist
for f in \
  lib/socialcounts.js lib/botapi.js lib/catalog.js lib/suggest.js lib/products.js lib/counts.js \
  routes/store.js routes/shop.js routes/catalog.js routes/products.js routes/product.js \
  routes/index.js routes/home.js routes/iptv.js \
  views/product.ejs views/catalog.ejs views/category.ejs views/home.ejs views/index.ejs views/shop.ejs \
  views/partials/product_card.ejs views/partials/card.ejs views/partials/suggestions.ejs \
  views/partials/suggest.ejs views/partials/related.ejs views/partials/top_strip.ejs; do
  [ -f "$GSZ/$f" ] && cp -f "$GSZ/$f" "$DST/$(echo "$f" | tr '/' '_')" && echo "copied $f"
done

# 3) where counts / suggestions actually render across the storefront
grep -rni "socialcount\|suggest\|related\|raw_live\|live_count\|\.have\b\|channels\|iptvcount\|lib_live\|libcount" \
  "$GSZ/routes" "$GSZ/lib" "$GSZ/views" --include=*.js --include=*.ejs 2>/dev/null \
  | grep -vi "node_modules" > "$DST/_grep_counts.txt" || true

cd /opt/gsz-deploy && git add -A && git commit -q -m "review snapshot: storefront cards/suggestions/counts" && git push -q && echo "PUSHED OK"
