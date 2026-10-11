#!/usr/bin/env bash
# GSZ — Admin Customers: add BULK actions (block / unblock / delete selected) across
# both models — a checkbox column + select-all + a bulk bar on desktop, and a per-card
# checkbox + bulk bar on mobile. Backend gets /admin/customers/bulk. The router mount,
# sidebar link and login block-check were already wired by stepCustomers.sh, so this
# just refreshes the route + view. Idempotent; validates; auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-custbulk-$TS"
cd "$GSZ"
FILES=(routes/adminCustomers.js views/admin/customers.ejs)
echo "==> backup -> $BK"
mkdir -p "$BK"; for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/adminCustomers.js" "$GSZ/routes/adminCustomers.js"
cp -f "$SRC/adm_customers.ejs" "$GSZ/views/admin/customers.ejs"

echo "==> validate"
node --check "$GSZ/routes/adminCustomers.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/views/admin/customers.ejs','utf8'),{filename:'$GSZ/views/admin/customers.ejs'});console.log('    customers ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Customers bulk actions live (select → Block / Unblock / Delete), both models."
