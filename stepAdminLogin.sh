#!/usr/bin/env bash
# GSZ — Admin login page: premium rebuild (centered card, Welcome back, your
# gradient-star logo + GSZ gradient, Hanken/Schibsted fonts loaded, gradient Sign In).
# Keeps the exact form (POST /admin/login, fields username+password) and the `error`
# var, so authentication is unchanged. Responsive on phone + desktop.
# View-only change. Idempotent; backs up; auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-adminlogin-$TS"; V=views/admin/login.ejs
cd "$GSZ"
echo "==> backup -> $BK/$V"
mkdir -p "$BK/$(dirname "$V")"; cp "$GSZ/$V" "$BK/$V"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$V" "$GSZ/$V"; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/adm_login.ejs" "$GSZ/$V"
node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/$V','utf8'),{filename:'$GSZ/$V'});console.log('    login ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Admin login rebuilt premium (/admin/login), auth unchanged, both models."
