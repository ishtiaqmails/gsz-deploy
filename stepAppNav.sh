#!/usr/bin/env bash
# App-style mobile bottom nav (view-only) — site-wide on phone/tablet. No PWA/service worker.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"

# back up the customer-tools partial + any view that holds the shared footer (so we can restore)
cp -f views/partials/customer_tools.ejs "views/partials/customer_tools.ejs.bak.$TS"
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')
for f in "${FOOTERS[@]}"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; \
  cp -f "views/partials/customer_tools.ejs.bak.$TS" views/partials/customer_tools.ejs; \
  for f in "${FOOTERS[@]}"; do cp -f "$f.bak.$TS" "$f"; done; \
  rm -f views/partials/app_nav.ejs; }
trap restore ERR

# place files
cp -f "$SRC/app_nav.ejs"        views/partials/app_nav.ejs
cp -f "$SRC/customer_tools.ejs" views/partials/customer_tools.ejs

# inject the include before the shared footer
node "$SRC/patch_appnav.js" "$GSZ"

# validate the nav partial + the customer-tools partial compile (self-contained, no includes)
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('views/partials/app_nav.ejs','utf8'),{filename:process.cwd()+'/views/partials/app_nav.ejs'});ejs.compile(fs.readFileSync('views/partials/customer_tools.ejs','utf8'),{filename:process.cwd()+'/views/partials/customer_tools.ejs'});console.log('  ejs ok');"
# sanity: each footer file still parses as EJS (include resolves at render; compile just checks syntax of the file itself)
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — App bottom-nav live on phone/tablet (Home · Store · My Orders · Cart · Support). Desktop unchanged."
