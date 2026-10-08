#!/usr/bin/env bash
# dumpH3 — the two pieces the earlier paste dropped from the top:
#   store_top.ejs (whole header/offer/hero wrapper) + home.ejs lines 1-72 (hero).
GSZ=/opt/gsz; cd "$GSZ"
echo "########## views/partials/store_top.ejs ($(wc -l < views/partials/store_top.ejs) lines) ##########"
cat -n views/partials/store_top.ejs
echo
echo "########## views/home.ejs  [lines 1-72 only] ##########"
sed -n '1,72p' views/home.ejs | cat -n
