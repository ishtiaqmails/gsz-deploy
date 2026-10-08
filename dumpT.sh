#!/usr/bin/env bash
# dumpT — the public /trials page view + the route that renders it (stray "Sign in" label).
GSZ=/opt/gsz; cd "$GSZ"
echo "########## views/trials.ejs ($(wc -l < views/trials.ejs) lines) ##########"
cat -n views/trials.ejs
echo
echo "########## route that renders 'trials' (public) ##########"
grep -rn "render('trials'" routes/*.js 2>/dev/null
echo
echo "########## context around that render (the public trials handler) ##########"
grep -rln "render('trials'" routes/*.js 2>/dev/null | while read f; do
  echo "----- $f -----"
  grep -n "render('trials'" "$f" | head -1
done
