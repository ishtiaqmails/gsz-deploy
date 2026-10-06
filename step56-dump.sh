#!/usr/bin/env bash
# READ ONLY — admin categories + products list views, and admin route mounts.
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing)"; echo "========== END $1 =========="; }
dump "$APP/views/admin/categories.ejs"
dump "$APP/views/admin/products.ejs"
echo; echo "========== categories schema =========="
( sudo -u postgres psql -d gsz -c "\d categories" 2>&1 || psql -U gsz_user -d gsz -c "\d categories" 2>&1 ) | head -40
echo "== DONE =="
