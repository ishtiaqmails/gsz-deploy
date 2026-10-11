#!/usr/bin/env bash
# Galaxy Hub — Deploy U: (1) the renew checkout inside the Hub now shows payment methods as the same
# square LOGO TILES as the main checkout (was a plain list); (2) retire the orphaned dashboard
# sub-pages (/account/orders|products|codes|security|support) — they now redirect into the Hub too.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
ACC=routes/account.js
cp -f "$HM" "$HM.bak.$TS"; cp -f "$ACC" "$ACC.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; cp -f "$ACC.bak.$TS" "$ACC"; }
trap restore ERR
cp -f "$SRC/hub_model.ejs" "$HM"
node "$SRC/patch_accredirect.js" "$GSZ"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub_model ejs ok');"
node --check "$ACC"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy U: renew checkout logo tiles + dashboard sub-pages retired to the Hub."
