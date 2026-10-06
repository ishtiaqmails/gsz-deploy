#!/usr/bin/env bash
# READ ONLY — category + orders routes/views for pagination.
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing)"; echo "========== END $1 =========="; }
dump "$APP/routes/category.js"
dump "$APP/views/category.ejs"
dump "$APP/routes/adminOrders.js"
echo "== DONE =="
