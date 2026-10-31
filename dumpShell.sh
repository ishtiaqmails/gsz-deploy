#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "partials/store_top.ejs (FULL — the head+header+nav shell; need exact locals)"
cat "$GSZ/views/partials/store_top.ejs"

sec "partials/store_bottom.ejs (FULL — footer + scripts, incl price painting)"
cat "$GSZ/views/partials/store_bottom.ejs"

sec "EXISTING SEO subsystem — exports only (cheap), to integrate not duplicate"
for f in indexnow indexnow_auto semclient seo_qa; do
  echo "### lib/$f.js — exports + key fns"
  grep -nE "module.exports|exports\.[a-zA-Z]|async function [a-zA-Z]|^function [a-zA-Z]|getKey|submit|ping" "$GSZ/lib/$f.js" 2>/dev/null | head -20
done
echo "### routes/sitemap.js — what it serves"
grep -nE "router\.(get|post)\(|res\.(type|send|render)|sitemap|robots|\.xml|SELECT" "$GSZ/routes/sitemap.js" 2>/dev/null | head -25
