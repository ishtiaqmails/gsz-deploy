#!/usr/bin/env bash
# hero fast-load — exact anchors. read-only.
GSZ=/opt/gsz; cd "$GSZ"
echo "### home.ejs hero block (exact, 18-40) ###"
sed -n '18,40p' views/home.ejs
echo
echo "### which route renders home + builds heroCats/bannerMap ###"
grep -rn "render('home'\|heroCats\|bannerMap" routes/*.js | grep -v "\.bak" | head
echo
echo "### head partial location (preload goes here) ###"
grep -rln "<head\|rel=\"preload\"\|name=\"viewport\"" views/partials/*.ejs 2>/dev/null | head
echo "--- head partial top (first match) ---"
HD=$(grep -rln "<head" views/partials/*.ejs 2>/dev/null | head -1)
echo "head file: ${HD:-<none>}"
[ -n "$HD" ] && grep -n "<head\|preload\|</head>\|stylesheet\|<title" "$HD" | head -20
echo
echo "### banner file sizes (is PNG weight the issue?) ###"
ls -laS static/img/banner-* 2>/dev/null | head -12 | awk '{print $5, $9}'
