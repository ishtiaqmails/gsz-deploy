#!/usr/bin/env bash
# dumpProdImg — how product images are stored + served (to wire REAL photos into the dashboard). SHORT.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "## products image-related columns ##"
Q -tAc "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='products' AND column_name ~* 'image|img|logo|icon|photo|pic'" 2>&1

echo "## sample product image values ##"
Q -c "SELECT id, left(name,22) AS name, image FROM products WHERE image IS NOT NULL AND image<>'' ORDER BY id LIMIT 6" 2>&1 | head -15

echo "## how image URL is built (storefront.js) ##"
grep -nE "image|/uploads|/img|/static|product.*img|imgUrl|image_url" lib/storefront.js 2>/dev/null | head -15

echo "## static mounts (server.js) ##"
grep -nE "express\.static|/uploads|/img|/static|/public|/media" server.js 2>/dev/null | head -12

echo "## how a store view renders a product image (any view) ##"
grep -rnoE "src=\"[^\"]*(image|img|uploads|logo)[^\"]*\"|<%= *[a-zA-Z_.]*(image|img|logo)[a-zA-Z_.]* *%>" views/ 2>/dev/null | grep -v '\.bak' | head -10

echo "## SITE LOGO: setting value + how store_top renders it ##"
Q -c "SELECT key, value FROM wa_settings WHERE key ~* 'logo'" 2>&1 | head
grep -nE "logo|<img" views/partials/store_top.ejs 2>/dev/null | head -10
echo "## logo file on disk? ##"
ls -1 public/ 2>/dev/null | grep -iE 'logo' ; ls -1 public/img/ 2>/dev/null | grep -iE 'logo' ; ls -1 uploads/ 2>/dev/null | grep -iE 'logo'
echo "== dumpProdImg done =="
