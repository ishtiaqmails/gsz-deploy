#!/usr/bin/env bash
# GSZ — Admin: Reports & analytics (premium mobile + desktop model, real data).
# Stat cards (today/week/month/all-time sales + orders, customers, open orders),
# a revenue/orders business graph with ranges (14d/1m/3m/6m/1y/all), Top Products,
# Top Customers. Read-only over orders/products/customers; touches nothing else.
#   NEW:     routes/adminReports.js, views/admin/reports.ejs
#   PATCHED: server.js (mount), views/admin/_shell_top.ejs (nav under Overview)
# Idempotent; backs up, validates, auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-reports-$TS"; TMP=$(mktemp -d)
cd "$GSZ"
PATCHED=(server.js views/admin/_shell_top.ejs)
NEW=(routes/adminReports.js views/admin/reports.ejs)
echo "==> backup -> $BK"
mkdir -p "$BK"
for f in "${PATCHED[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
NEWHAD=()
for f in "${NEW[@]}"; do if [ -f "$GSZ/$f" ]; then NEWHAD+=("$f"); mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; fi; done
restore(){
  echo "!! FAILED — restoring"
  for f in "${PATCHED[@]}"; do cp "$BK/$f" "$GSZ/$f"; done
  for f in "${NEW[@]}"; do keep=0; for h in "${NEWHAD[@]:-}"; do [ "$h" = "$f" ] && keep=1; done
    if [ "$keep" = "1" ]; then cp "$BK/$f" "$GSZ/$f"; else rm -f "$GSZ/$f"; fi; done
  pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."
}
trap 'restore' ERR

cp -f "$SRC/adminReports.js" "$GSZ/routes/adminReports.js"
cp -f "$SRC/adm_reports.ejs" "$GSZ/views/admin/reports.ejs"
cp -f "$SRC/patch_reports.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/adminReports.js"
node --check "$GSZ/server.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/reports.ejs','views/admin/_shell_top.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — Admin → Reports live (/admin/reports), both models, real data."
