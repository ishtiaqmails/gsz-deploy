#!/usr/bin/env bash
# Galaxy Hub — Deploy Q (account dashboard -> app model): the /account dashboard now follows the
# site model. It includes the shared bottom app bar + ticker (mobile only; desktop keeps its layout),
# its Quick Access tiles open the shared Hub modal (popup on desktop, sheet on mobile) instead of the
# old duplicate popup, the redundant My Orders tile is gone, and Free Trials opens the Hub's trials
# tab. Removes the dashboard's duplicated Customer Tools popup. View only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
V=views/account/dashboard.ejs
cp -f "$V" "$V.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$V.bak.$TS" "$V"; }
trap restore ERR
cp -f "$SRC/acc_dashboard.ejs" "$V"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$V','utf8'),{filename:process.cwd()+'/'+'$V'});console.log('  dashboard ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy Q: /account dashboard follows the app model (app bar + Hub, no page-jump tiles)."
