#!/usr/bin/env bash
# Read-only: shows the home route render + the shared head so Claude can write a precise SEO patch.
GSZ=/opt/gsz; cd "$GSZ"
echo "===== HOME RENDER ====="
grep -rn "res.render('home'" server.js routes/*.js 2>/dev/null | head
HF=$(grep -rl "res.render('home'" server.js routes/*.js 2>/dev/null | head -1)
echo "-- file: $HF --"
[ -n "$HF" ] && awk "/res\.render\('home'/{f=NR} f&&NR>=f-8&&NR<=f+10{print NR\": \"\$0}" "$HF" | head -22
echo
echo "===== store_top.ejs <head> ====="
ST=views/partials/store_top.ejs
awk '/<head/{f=1} f{print NR": "$0} /<\/head>/{if(f)exit}' "$ST" | head -60
