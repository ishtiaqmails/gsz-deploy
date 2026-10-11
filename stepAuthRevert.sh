#!/usr/bin/env bash
# GSZ — REVERT the customer auth visual change. Restore the original Sign in / Create
# account / Forgot / Reset views (your customer model — store chrome, your colours) from
# the backup taken during stepAuthRebuild, and remove the admin-style partials I added.
# Keeps ONLY the no-account routing behaviour you asked for (shows "No account found" on
# the Forgot page instead of the code page) — that changes no colours or layout.
set -Eeuo pipefail
GSZ=/opt/gsz
BK=$(ls -d "$GSZ"/.bak-authrebuild-* 2>/dev/null | sort | tail -1)
[ -n "$BK" ] || { echo "!! no auth-rebuild backup found — cannot auto-revert"; exit 1; }
echo "==> restoring original customer auth views from $BK"
for f in login signup forgot reset; do
  [ -f "$BK/views/account/$f.ejs" ] && cp -f "$BK/views/account/$f.ejs" "$GSZ/views/account/$f.ejs" && echo "   restored $f.ejs"
done
rm -f "$GSZ/views/partials/auth2_top.ejs" "$GSZ/views/partials/auth2_bottom.ejs" && echo "   removed admin-style partials"
echo "==> validate"
node -e "const ejs=require('$GSZ/node_modules/ejs');['login','signup','forgot','reset'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/views/account/'+f+'.ejs','utf8'),{filename:'$GSZ/views/account/'+f+'.ejs'});console.log('   ejs ok '+f)})"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — customer auth pages back to your customer model (nothing visual changed). Only the no-account routing fix remains."
