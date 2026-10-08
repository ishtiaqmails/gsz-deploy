#!/usr/bin/env bash
# dumpQA — enumerate the dead `btn-p` class + any other undefined button classes.
GSZ=/opt/gsz; cd "$GSZ"

echo "########## every real 'btn-p' token (NOT btn-primary) in views ##########"
grep -rnoE 'btn-p([^a-z-]|$)' views routes public 2>/dev/null | sort | uniq -c | sort -rn
echo
echo "########## files + lines using btn-p (precise) ##########"
grep -rnE 'btn-p([^a-z-]|$)' views routes public 2>/dev/null

echo
echo "########## is btn-p defined in ANY css? ##########"
grep -rn '\.btn-p' public/css 2>/dev/null || echo "  (no .btn-p rule found in public/css)"
echo
echo "########## all .btn-* rules DEFINED in app.css + cart.css ##########"
grep -rnoE '\.btn-[a-z-]+' public/css 2>/dev/null | sort -u

echo
echo "########## all btn-* classes USED across views (tokens) ##########"
grep -rhoE 'class="[^"]*btn[^"]*"' views 2>/dev/null | grep -oE 'btn-[a-z0-9-]+' | sort | uniq -c | sort -rn

echo
echo "########## public/css/cart.css ($(wc -l < public/css/cart.css) lines) ##########"
cat -n public/css/cart.css
