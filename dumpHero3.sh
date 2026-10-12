#!/usr/bin/env bash
# hero fast-load — final anchors. read-only.
GSZ=/opt/gsz; cd "$GSZ"
echo "### home.ejs 38-58 (the <img> inside <picture> + slide close) ###"
sed -n '38,58p' views/home.ejs
echo
echo "### store_top.ejs head (1-70) — where preload + stylesheet live ###"
sed -n '1,70p' views/partials/store_top.ejs
echo
echo "### home route: heroCats/bannerMap + render ###"
grep -rn "render('home'\|render(\"home\"\|heroCats\|bannerMap" routes/*.js app.js index.js server.js 2>/dev/null | grep -v "\.bak" | head
echo
echo "### banner files: real path + sizes (bytes) ###"
find . -name 'banner-*' -not -path '*/node_modules/*' -printf '%s %p\n' 2>/dev/null | sort -rn | head -12
