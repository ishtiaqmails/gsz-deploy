#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "A) resellers.ejs — how panel prices + the credit calculator render (FULL)"
cat "$GSZ/views/resellers.ejs" 2>/dev/null | sed -n '1,400p'

sec "A2) where /resellers is handled + what it passes"
grep -rnE "resellers'|\"resellers\"|res\.render\('resellers|reseller_panels|panels" "$GSZ/routes/marketing.js" "$GSZ/routes/pages.js" 2>/dev/null | head -20

sec "B) admin nav shell — admin/_shell_top.ejs (FULL, the nav list)"
cat "$GSZ/views/admin/_shell_top.ejs" 2>/dev/null | sed -n '1,220p'

sec "B2) EVERY admin page URL (router.get across all admin routers)"
for f in "$GSZ"/routes/admin*.js "$GSZ"/routes/botAdmin.js "$GSZ"/routes/wabot.js "$GSZ"/routes/csAdmin.js; do
  [ -f "$f" ] || continue
  echo "### $(basename "$f")"
  grep -nE "router\.(get)\(" "$f" | grep -vE "/login|/logout|\.json|/api/|/data" | head -14
done

sec "C) failed Mega OTT order today — app log (bounded)"
pm2 logs gsz --nostream --lines 4000 2>/dev/null | grep -iE "mega|order.*fail|deliver.*fail|provision.*error|error.*mega" | tail -40
echo "--- (if empty, the failure may be on the reseller bot, not the site) ---"
