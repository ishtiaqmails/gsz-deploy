#!/usr/bin/env bash
# Galaxy Hub — Deploy T: restyle the Quick Access box — richer blue->purple->cyan gradient, brighter
# accent border, soft glow + a radial highlight so it draws the eye. customer_tools partial only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
cp -f "$CT" "$CT.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$CT.bak.$TS" "$CT"; }
trap restore ERR
cp -f "$SRC/customer_tools.ejs" "$CT"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$CT','utf8'),{filename:process.cwd()+'/'+'$CT'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy T: Quick Access box restyled (vibrant gradient + glow)."
