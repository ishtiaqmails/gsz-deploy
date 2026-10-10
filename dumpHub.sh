#!/usr/bin/env bash
# dumpHub — backend facts needed to build the Galaxy Hub redesign (auth, profile, announcements, trials).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tAc "$1" 2>&1; }

echo "#### 1. account.js — all routes + login/logout/profile-update ####"
grep -nE "router\.(get|post)\(['\"][^'\"]+|logout|/login|/register|session\.customer *=" routes/account.js | head -50

echo "#### 2. customers table columns ####"
Q "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='customers'"

echo "#### 3. announcements — routes (public fetch) ####"
grep -rnE "announc" routes/*.js server.js 2>/dev/null | grep -iE "router\.(get|post)|app\.(get|post)|/api|announcements" | head -20
echo "-- announcements table columns --"
Q "SELECT table_name||': '||string_agg(column_name,', ') FROM information_schema.columns WHERE table_name ILIKE '%announc%' GROUP BY table_name"

echo "#### 4. trials — routes + tables + columns ####"
grep -rnE "/api/trials|/trial|trial" routes/*.js 2>/dev/null | grep -iE "router\.(get|post)\(|/api/trial|/trial" | head -25
echo "-- trial tables --"
Q "SELECT string_agg(table_name,', ') FROM information_schema.tables WHERE table_name ILIKE '%trial%'"
echo "-- columns per trial table --"
for t in $(Q "SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%trial%'"); do echo "  $t: $(Q "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='$t'")"; done
echo "-- /api/trials live response (shape) --"
curl -s "http://127.0.0.1:3900/api/trials" 2>/dev/null | head -c 500; echo

echo "#### 5. settings keys (wa numbers / support / chat) ####"
Q "SELECT key FROM settings WHERE key ILIKE '%wa%' OR key ILIKE '%support%' OR key ILIKE '%chat%' OR key ILIKE '%number%'" 2>/dev/null | head -15

echo "#### 6. how store_bottom includes scripts (for app.js version + where to add ticker) ####"
grep -nE "app\.js|customer_tools|announc|<script|include\(" views/partials/store_bottom.ejs | head -20
echo "== dumpHub done =="
