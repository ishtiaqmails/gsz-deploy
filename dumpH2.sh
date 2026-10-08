#!/usr/bin/env bash
# dumpH2 — print the homepage view + its wrapper partials + main CSS.
GSZ=/opt/gsz; cd "$GSZ"
for f in views/partials/store_top.ejs views/home.ejs views/partials/store_bottom.ejs public/css/app.css; do
  echo "########## $f ($(wc -l < "$f") lines) ##########"
  cat -n "$f"
  echo
done
