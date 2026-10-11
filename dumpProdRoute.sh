#!/usr/bin/env bash
# dumpProdRoute — locate the PUBLIC product-page route that renders views/product.ejs and builds `plans`,
# so a per-plan `popular` field can be passed through. Small + targeted.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## files that render the product view ##########"
grep -rln "render('product'" --include=*.js . 2>/dev/null
echo "########## the product route + its plan build (context) ##########"
f=$(grep -rln "render('product'" --include=*.js . 2>/dev/null | head -1)
echo "FILE: $f"
if [ -n "$f" ]; then
  ln=$(grep -n "render('product'" "$f" | head -1 | cut -d: -f1)
  start=$((ln-45)); [ "$start" -lt 1 ] && start=1
  sed -n "${start},$((ln+3))p" "$f"
fi
echo "== dumpProdRoute done =="
