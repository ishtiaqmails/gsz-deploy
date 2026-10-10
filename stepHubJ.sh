#!/usr/bin/env bash
# Galaxy Hub — Deploy J (audit): header account / sign-in / create-account links now open the
# Hub model site-wide instead of navigating to /account, /login, /signup. hub_model partial only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')
cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR

cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub_model ejs ok');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy J: header account/sign-in links open the Hub model site-wide."
