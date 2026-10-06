#!/usr/bin/env bash
# step41-dump — READ ONLY. Prints product.ejs + order.ejs so the cart can extend them safely.
set -euo pipefail
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing: $1)"; echo "========== END $1 =========="; }
dump "$APP/views/product.ejs"
dump "$APP/views/order.ejs"
echo; echo "== DONE =="
