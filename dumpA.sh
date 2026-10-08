#!/usr/bin/env bash
# dumpA — the About page view + the route that renders it (awkward/centered layout fix).
GSZ=/opt/gsz; cd "$GSZ"
echo "########## views/about.ejs ($(wc -l < views/about.ejs) lines) ##########"
cat -n views/about.ejs
echo
echo "########## route that renders 'about' ##########"
grep -rn "render('about'" routes/*.js 2>/dev/null
