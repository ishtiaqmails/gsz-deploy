#!/usr/bin/env bash
# GSZ — Admin password reset (code via gszwabot to the OWNER WhatsApp number).
#   "Forgot password?" on login -> /admin/forgot (Send Reset Code) -> code to owner WhatsApp
#   -> /admin/reset (enter code + new password) -> password saved as a hash in admin_auth.
#   Login (routes/admin.js) checks admin_auth first, falls back to .env ADMIN_PASS.
#   Owner number read live from wa_settings (editable in Admin → WhatsApp → Numbers).
#   NEW:     routes/adminReset.js, views/admin/forgot.ejs, views/admin/reset.ejs
#   PATCHED: server.js (mount), routes/admin.js (login), views/admin/login.ejs (forgot link)
#   MIGRATION: admin_auth, admin_reset tables
# Idempotent; backs up, validates, auto-restores on failure. Nothing hardcoded.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-adminreset-$TS"; TMP=$(mktemp -d)
cd "$GSZ"

PATCHED=(server.js routes/admin.js views/admin/login.ejs)
NEW=(routes/adminReset.js views/admin/forgot.ejs views/admin/reset.ejs)

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
cp -f "$SRC/adminReset.js" "$GSZ/routes/adminReset.js"
cp -f "$SRC/adm_forgot.ejs" "$GSZ/views/admin/forgot.ejs"
cp -f "$SRC/adm_reset.ejs" "$GSZ/views/admin/reset.ejs"
cp -f "$SRC/adm_login.ejs" "$GSZ/views/admin/login.ejs"

echo "==> migrate (admin_auth, admin_reset)"
cat > "$TMP/m.js" <<'JS'
'use strict';
require('dotenv/config');
const { Pool } = require('pg');
const pool = new Pool({ host: process.env.DB_HOST || '127.0.0.1', port: +(process.env.DB_PORT || 5432), user: process.env.DB_USER, password: process.env.DB_PASS, database: process.env.DB_NAME });
(async () => {
  await pool.query("CREATE TABLE IF NOT EXISTS admin_auth(id int PRIMARY KEY, pass_hash text, updated_at timestamptz DEFAULT now())");
  await pool.query("CREATE TABLE IF NOT EXISTS admin_reset(id serial PRIMARY KEY, code text NOT NULL, expires_at timestamptz NOT NULL, used boolean NOT NULL DEFAULT false, tries int NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now())");
  console.log('    migration ok (admin_auth, admin_reset)');
  await pool.end();
})().catch(e => { console.error('MIGRATION FAIL: ' + e.message); process.exit(1); });
JS
( cd "$GSZ" && NODE_PATH="$GSZ/node_modules" node "$TMP/m.js" )

echo "==> apply patches"
cp -f "$SRC/patch_adminreset.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/adminReset.js"
node --check "$GSZ/routes/admin.js"
node --check "$GSZ/server.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/forgot.ejs','views/admin/reset.ejs','views/admin/login.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — Admin password reset live (Forgot password -> code from bot -> reset). Login unchanged until you reset."
