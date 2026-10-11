#!/usr/bin/env bash
# GSZ — Admin Customers: client-side PAGINATION (20 per page) matching the Products
# section — a numbered pager that works together with search + the filter tabs; select-all
# applies to the current page while the selection persists across pages. View-only change
# (the /admin/customers/bulk route is unchanged). Idempotent; validates; auto-restores.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-custpage-$TS"; V=views/admin/customers.ejs
cd "$GSZ"
echo "==> backup -> $BK/$V"
mkdir -p "$BK/$(dirname "$V")"; cp "$GSZ/$V" "$BK/$V"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$V" "$GSZ/$V"; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/adm_customers.ejs" "$GSZ/$V"
node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/$V','utf8'),{filename:'$GSZ/$V'});console.log('    customers ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Customers pagination live (20/page, works with search + filters), both models."
