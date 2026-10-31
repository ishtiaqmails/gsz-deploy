#!/usr/bin/env bash
# stepWaitlist.sh — admin restock-waitlist detail page (who waits for which product/plan).
#   Copies routes/adminWaitlist.js + views/admin/waitlist.ejs, mounts it, points the dashboard
#   "View ->" at it. Idempotent; restores (incl. new files) if health doesn't return.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(server.js views/admin/dashboard.ejs)
NEW=(routes/adminWaitlist.js views/admin/waitlist.ejs)
declare -A HAD; for n in "${NEW[@]}"; do [ -f "$GSZ/$n" ] && HAD[$n]=1 || HAD[$n]=0; done
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring";
  for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done
  for n in "${NEW[@]}"; do [ "${HAD[$n]}" = "0" ] && rm -f "$GSZ/$n" || true; done
  pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> copy new files"
cp -f "$SRC/adminWaitlist.js" "$GSZ/routes/adminWaitlist.js"
cp -f "$SRC/waitlist.ejs" "$GSZ/views/admin/waitlist.ejs"
echo "==> patch"
node "$SRC/patch_waitlist.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/routes/adminWaitlist.js" && echo "  adminWaitlist.js ok"
node --check "$GSZ/server.js" && echo "  server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs'),p=require('path');ejs.compile(fs.readFileSync('$GSZ/views/admin/waitlist.ejs','utf8'),{filename:p.resolve('$GSZ/views/admin/waitlist.ejs')});console.log('  waitlist.ejs compiles');"

trap - ERR
pm2 restart gsz --update-env >/dev/null
ok=0; for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { ok=1; echo "  health OK (${i}s)"; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "  health FAILED"; restore; exit 1; }
echo
echo "DONE — Admin → Dashboard → the 'waiting on restock' row now links to /admin/waitlist, which"
echo "lists each waiting customer with their product, plan and contact (Remove cancels one)."
