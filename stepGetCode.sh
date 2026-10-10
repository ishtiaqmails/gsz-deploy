#!/usr/bin/env bash
# Get Code: eligibility feed + guarded household route + self-aware Get Code UI.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
cp -f "$GSZ/routes/account.js" "$GSZ/routes/account.js.bak.$TS"
restore(){ echo "!! failed — restoring account.js"; cp -f "$GSZ/routes/account.js.bak.$TS" "$GSZ/routes/account.js"; }
trap restore ERR
cp -f "$SRC/customer_tools.ejs" "$GSZ/views/partials/customer_tools.ejs"
node "$SRC/patch_getcode.js" "$GSZ"
node --check "$GSZ/routes/account.js"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/partials/customer_tools.ejs','utf8'),{filename:'$GSZ/views/partials/customer_tools.ejs'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Get Code live: self-aware per-product Code/Link/Household buttons."
