#!/usr/bin/env bash
# dumpBuild — everything needed to build CLAIM (customer screenshot upload + admin approval console).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "#### 1. multer/upload config + uploads static mount ####"
grep -nE "multer|diskStorage|destination|dest:|upload *= *multer|express.static.*upload|/uploads|proof_file" routes/checkout.js server.js 2>/dev/null | head -18

echo "#### 2. how admin routes mount + admin auth ####"
grep -nE "adminIssues|requireAdmin|session\.admin|app\.use\(['\"]/admin|'/admin'|isAdmin" server.js routes/admin.js routes/adminIssues.js 2>/dev/null | head -25

echo "#### 3. inventory_items columns (for approve-from-stock) ####"
Q -tAc "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='inventory_items'" 2>&1

echo "#### 4. admin views present (issues / shell / nav) ####"
ls views/admin/ 2>/dev/null | grep -iE 'issue|shell|top|nav|layout|side|head|dash|replace' | head

echo "#### 5. routes/adminIssues.js (FULL) ####"
cat -n routes/adminIssues.js 2>/dev/null

echo "#### 6. admin issues view (FULL) ####"
IV=$(ls views/admin/ 2>/dev/null | grep -iE 'issue|replace' | head -1)
echo "-- file: views/admin/$IV --"
[ -n "$IV" ] && cat -n "views/admin/$IV"

echo "#### 7. admin shell/nav (how an admin page is wrapped + nav links) ####"
SH=$(ls views/admin/ 2>/dev/null | grep -iE 'shell|_top|layout|head' | head -1)
echo "-- shell file: views/admin/$SH --"
[ -n "$SH" ] && grep -nE "nav|href=|<a |sidebar|menu|include|Issues|Orders|Products|<title|logo" "views/admin/$SH" 2>/dev/null | head -40
echo "== dumpBuild done =="
