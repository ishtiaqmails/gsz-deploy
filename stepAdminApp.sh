#!/usr/bin/env bash
# Galaxy — Admin mobile app model: fixed bottom nav bar on phones/touch tablets (desktop sidebar
# unchanged). Patches the admin shell (_shell_top css + _shell_bottom bar). Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
T=views/admin/_shell_top.ejs; B=views/admin/_shell_bottom.ejs
cp -f "$T" "$T.bak.$TS"; cp -f "$B" "$B.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$T.bak.$TS" "$T"; cp -f "$B.bak.$TS" "$B"; }
trap restore ERR
node "$SRC/patch_adminapp.js" "$GSZ"
node -e "const ejs=require('ejs'),fs=require('fs');['$T','$B'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});console.log('  ejs ok:',f);});"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Admin mobile app model live: bottom nav bar on phones/tablets, desktop sidebar unchanged."
