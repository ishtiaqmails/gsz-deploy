#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "server.js :: view engine / layout / static / locals setup"
grep -nE "view engine|app\.set\(|express\.static|app\.locals|express-ejs-layouts|layout" "$GSZ/server.js" | head -40

sec "server.js :: ALL route mounts & handlers IN ORDER (app.use/get/post/all)"
grep -nE "app\.(use|get|post|all)\(" "$GSZ/server.js"

sec "server.js :: 404 / final handler (last 40 lines)"
tail -40 "$GSZ/server.js"

sec "routes/ dir"
ls "$GSZ/routes"

sec "WHERE is /category rendered? (server.js + routes)"
grep -rnE "category/:|'/category|\"/category|res\.render\(['\"]category" "$GSZ/server.js" "$GSZ/routes" 2>/dev/null | head -30

sec "category render handler — context around first match in server.js"
LINE=$(grep -nE "res\.render\(['\"]category" "$GSZ/server.js" | head -1 | cut -d: -f1)
if [ -n "${LINE:-}" ]; then sed -n "$((LINE>30?LINE-30:1)),$((LINE+10))p" "$GSZ/server.js"; else echo "(not in server.js — see routes grep above)"; fi

sec "views/ top-level + partials"
ls "$GSZ/views"; echo "--- partials ---"; ls "$GSZ/views/partials" 2>/dev/null

sec "category.ejs (full, capped 200 lines)"
head -200 "$GSZ/views/category.ejs"

sec "the shell: head/header partials — first 2 partials that look like layout"
for f in layout head header shell _head _shell top _shell_top; do
  [ -f "$GSZ/views/partials/$f.ejs" ] && { echo "### partials/$f.ejs (head 80)"; head -80 "$GSZ/views/partials/$f.ejs"; }
done

sec "storefront.js :: exported fns + category query"
ls "$GSZ/lib" 2>/dev/null
grep -nE "module.exports|exports\.|async function|function |SELECT .*categ|WHERE .*categ|category" "$GSZ/lib/storefront.js" 2>/dev/null | head -50
