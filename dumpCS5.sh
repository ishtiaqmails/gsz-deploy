#!/usr/bin/env bash
# dumpCS5 — everything CS-5 (Content Studio admin) needs to match the real /admin.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## 1. admin auth middleware (how routes gate) ##########"
sed -n '1,60p' routes/admin.js
echo
echo "########## 2. admin shell partials (names) ##########"
ls -la views/admin/ 2>/dev/null | head -40
echo
echo "########## 3. _shell_top.ejs (nav + theme + btn classes) ##########"
sed -n '1,200p' views/admin/_shell_top.ejs 2>/dev/null
echo
echo "########## 4. _shell_bottom.ejs ##########"
cat views/admin/_shell_bottom.ejs 2>/dev/null
echo
echo "########## 5. one real admin list view for pattern (adminCoupons or labels) ##########"
for f in coupons labels announcements; do [ -f "views/admin/$f.ejs" ] && { echo "=== views/admin/$f.ejs (head) ==="; sed -n '1,70p' "views/admin/$f.ejs"; break; }; done
echo
echo "########## 6. CS table schemas ##########"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
for t in cs_posts cs_authors cs_redirects cs_events cs_categories cs_tags; do
  echo "--- \d $t ---"; psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "\d $t" 2>/dev/null | sed -n '1,40p'
done
echo
echo "########## 7. how admin nav links are defined (grep) ##########"
grep -nE "href=\"/admin" views/admin/_shell_top.ejs 2>/dev/null | head -40
echo "== dumpCS5 done =="
