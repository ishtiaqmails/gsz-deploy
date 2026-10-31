#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "admin shell partials (how admin pages are wrapped)"
for f in dash_top dash_bottom; do
  echo "### partials/$f.ejs"; sed -n '1,120p' "$GSZ/views/partials/$f.ejs" 2>/dev/null || echo "(missing)"
done

sec "one admin router — adminWaitlist.js (auth + mount + render pattern)"
sed -n '1,80p' "$GSZ/routes/adminWaitlist.js" 2>/dev/null || echo "(missing)"

sec "admin auth middleware (how /admin is protected) — search server.js + admin.js"
grep -nE "requireAdmin|isAdmin|admin.*auth|session.*admin|req.session.admin|adminGuard|res.redirect\('/admin/login'|password" "$GSZ/server.js" "$GSZ/routes/admin.js" 2>/dev/null | head -25

sec "routes/sitemap.js (FULL — to add geo_pages into the existing sitemap)"
cat "$GSZ/routes/sitemap.js" 2>/dev/null || echo "(missing)"

sec "lib/indexnow.js (FULL — to wire geo publish pings correctly)"
cat "$GSZ/lib/indexnow.js" 2>/dev/null || echo "(missing)"

sec "an admin dashboard view (to match look) — list admin views"
ls "$GSZ/views/admin" 2>/dev/null | head -40
