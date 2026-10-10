#!/usr/bin/env bash
# Home page: install Customer Tools partial, remove promo band + add include, validate, restart.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
cp -f "$GSZ/views/home.ejs" "$GSZ/views/home.ejs.bak.$TS"
restore(){ echo "!! failed — restoring home.ejs"; cp -f "$GSZ/views/home.ejs.bak.$TS" "$GSZ/views/home.ejs"; }
trap restore ERR

echo "== install Customer Tools partial =="
cp -f "$SRC/customer_tools.ejs" "$GSZ/views/partials/customer_tools.ejs"

echo "== patch home.ejs (remove promo band + add include) =="
node "$SRC/patch_home.js" "$GSZ"

echo "== validate EJS =="
node -e "const ejs=require('ejs'),fs=require('fs');['views/partials/customer_tools.ejs','views/home.ejs'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('  ejs ok '+f);});"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done
echo "DONE — reload the HOME page: Quick Access Customer Tools band is under the hero, tiles open the pop-up."
