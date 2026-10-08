#!/usr/bin/env bash
# dumpH — discover + print the homepage view(s) and main CSS for the premium pass.
GSZ=/opt/gsz; cd "$GSZ"

echo "########## VIEWS TREE ##########"
find views -maxdepth 2 -type f | sort
echo
echo "########## PUBLIC CSS/JS TREE ##########"
find public -maxdepth 3 -type f \( -name '*.css' -o -name '*.js' \) | sort
echo
echo "########## GREP: homepage anchors ##########"
grep -rln -e "Shop by category" -e "Premium Entertainment" -e "Most popular" -e "Average customer rating" views 2>/dev/null
echo
echo "########## WHICH VIEW DOES / RENDER ##########"
grep -rn -e "res.render(" routes/*.js 2>/dev/null | grep -iE "home|index|store|'/'|pages" | head -30
