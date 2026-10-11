#!/usr/bin/env bash
# GSZ — Admin rebuild: Customers section (NEW) in the premium mobile + desktop model.
# GSZ customers have no wallet/VIP/types, so this mirrors the reseller Customers layout
# with GSZ's real fields: identity, WhatsApp + email verification, order count, join date,
# a detail modal (recent orders), block/unblock (enforced at login), delete.
#   NEW:     routes/adminCustomers.js, views/admin/customers.ejs
#   PATCHED: server.js (mount), views/admin/_shell_top.ejs (nav), routes/account.js (login block)
#   MIGRATION: customers.blocked boolean (default false)
# Idempotent; backs up, validates, auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-customers-$TS"; TMP=$(mktemp -d)
cd "$GSZ"

PATCHED=(server.js views/admin/_shell_top.ejs routes/account.js)
NEW=(routes/adminCustomers.js views/admin/customers.ejs)

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

echo "==> copy new files"
cp -f "$SRC/adminCustomers.js" "$GSZ/routes/adminCustomers.js"
cp -f "$SRC/adm_customers.ejs" "$GSZ/views/admin/customers.ejs"

echo "==> migrate (customers.blocked)"
cat > "$TMP/m.js" <<'JS'
'use strict';
require('dotenv/config');
const { Pool } = require('pg');
const pool = new Pool({ host: process.env.DB_HOST || '127.0.0.1', port: +(process.env.DB_PORT || 5432), user: process.env.DB_USER, password: process.env.DB_PASS, database: process.env.DB_NAME });
(async () => {
  await pool.query("ALTER TABLE customers ADD COLUMN IF NOT EXISTS blocked boolean NOT NULL DEFAULT false");
  console.log('    migration ok (customers.blocked)');
  await pool.end();
})().catch(e => { console.error('MIGRATION FAIL: ' + e.message); process.exit(1); });
JS
( cd "$GSZ" && NODE_PATH="$GSZ/node_modules" node "$TMP/m.js" )

echo "==> apply patches"
cp -f "$SRC/patch_customers.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/adminCustomers.js"
node --check "$GSZ/routes/account.js"
node --check "$GSZ/server.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/customers.ejs','views/admin/_shell_top.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — Admin → Customers built in the premium mobile + desktop model (/admin/customers)."
