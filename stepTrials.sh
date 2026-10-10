#!/usr/bin/env bash
# Batch 2 — Trials in the Hub: credentials + 2-day Extend (bot-wired, graceful) + Convert-to-paid.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
NAV=views/partials/app_nav.ejs
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')

cp -f routes/account.js "routes/account.js.bak.$TS"
cp -f lib/botapi.js "lib/botapi.js.bak.$TS"
cp -f "$CT" "$CT.bak.$TS"; cp -f "$NAV" "$NAV.bak.$TS"
for f in "${FOOTERS[@]}"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; cp -f "routes/account.js.bak.$TS" routes/account.js; cp -f "lib/botapi.js.bak.$TS" lib/botapi.js; cp -f "$CT.bak.$TS" "$CT"; cp -f "$NAV.bak.$TS" "$NAV"; for f in "${FOOTERS[@]}"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR

node "$SRC/patch_botapi.js" lib/botapi.js
node "$SRC/patch_trials.js" "$GSZ"
cp -f "$SRC/customer_tools.ejs" "$CT"
cp -f "$SRC/app_nav.ejs" "$NAV"
node "$SRC/patch_appnav.js" "$GSZ"

node --check routes/account.js
node --check lib/botapi.js
node -e "const ejs=require('ejs'),fs=require('fs');['$CT','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  hub ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Trials in Hub live: credentials + 2-day Extend (from claim) + Convert-to-paid."
