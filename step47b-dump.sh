#!/usr/bin/env bash
# READ ONLY — product editor route + view + product route, for geo_note (#2).
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing)"; echo "========== END $1 =========="; }
dump "$APP/routes/adminCatalog.js"
dump "$APP/views/admin/product_edit.ejs"
dump "$APP/routes/products.js"
echo "== DONE =="
