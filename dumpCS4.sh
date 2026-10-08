#!/usr/bin/env bash
# dumpCS4 — everything CS-4 (sitemap/robots) needs, from the LIVE app.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## 1. route mounts in server.js ##########"
grep -nE "app\.(use|get)\(|express\.static|require\('\./routes" server.js
echo
echo "########## 2. GET routes in routes/pages.js ##########"
grep -nE "router\.(get|use)\(" routes/pages.js 2>/dev/null
echo
echo "########## 3. product & category route lines (any routes file) ##########"
grep -rnE "/product/|/category/|'/product'|'/category'|:slug" routes/*.js | head -40
echo
echo "########## 4. static-file middleware + public contents ##########"
grep -nE "express\.static|'/static'|public" server.js
echo "--- public/ top ---"; ls -la public/ 2>/dev/null | head
echo "--- existing robots/sitemap? ---"; ls -la public/ 2>/dev/null | grep -iE "robots|sitemap"; find . -maxdepth 2 -iname "sitemap*" -o -iname "robots*" 2>/dev/null | grep -v node_modules | head
echo
echo "########## 5. SITE_DOMAIN / base-url env (value shown) ##########"
grep -iE "SITE_DOMAIN|BASE_URL|SITE_URL|DOMAIN|PUBLIC_URL" .env 2>/dev/null
echo
echo "########## 6. columns I rely on ##########"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "\d products"   2>/dev/null | grep -E "slug|active|hidden|updated_at|category_id|name"
echo "--- categories ---"; psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "\d categories" 2>/dev/null | grep -E "slug|active|name|updated_at"
echo "--- cs_posts counts by status ---"; psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tc "SELECT status,count(*) FROM cs_posts GROUP BY status" 2>/dev/null
echo "--- live product/category sample URLs ---"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tc "SELECT '/product/'||slug FROM products WHERE active AND NOT hidden LIMIT 3" 2>/dev/null
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tc "SELECT '/category/'||slug FROM categories WHERE active LIMIT 3" 2>/dev/null
echo "== dumpCS4 done =="
