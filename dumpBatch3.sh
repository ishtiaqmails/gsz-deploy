#!/usr/bin/env bash
# dumpBatch3 — branding, content(marquee), announcements, marketing views + render locals.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
for v in branding content announcements marketing; do
  echo "########## views/admin/$v.ejs ##########"; cat "views/admin/$v.ejs" 2>&1; echo
done
echo "########## render signatures ##########"
echo "--- admin.js (branding + content handlers) ---"
grep -nE "router\.(get|post)\('/(branding|content)|res\.render\('admin/(branding|content)" routes/admin.js
echo "--- adminAnnouncements.js ---"; grep -nE "router\.(get|post)\(|res\.render" routes/adminAnnouncements.js
echo "--- marketing.js ---"; grep -nE "router\.(get|post)\(|res\.render" routes/marketing.js
echo "== dumpBatch3 done =="
