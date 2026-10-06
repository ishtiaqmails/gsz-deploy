#!/usr/bin/env bash
# step39-dump — READ ONLY. Prints the files needed to rebuild checkout. Changes nothing.
set -euo pipefail
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing: $1)"; echo "========== END $1 =========="; }

dump "$APP/views/partials/store_top.ejs"
dump "$APP/views/partials/store_bottom.ejs"
echo; echo "========== BEGIN app.css :root + nav/footer (first 160 lines) =========="
sed -n '1,160p' "$APP/public/css/app.css" 2>/dev/null || echo "(css path differs)"
echo "========== END app.css excerpt =========="
echo; echo "========== BEGIN checkout.js route (live) =========="
cat "$APP/routes/checkout.js" 2>/dev/null || echo "(missing)"
echo "========== END checkout.js =========="
echo; echo "== DONE =="
