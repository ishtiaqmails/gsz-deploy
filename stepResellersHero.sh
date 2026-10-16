#!/usr/bin/env bash
# stepResellersHero.sh — add a Reseller Panels hero banner using the existing Branding & Banners system.
#   Patches routes/admin.js (new banner slot) + routes/pages.js (load bannerMap).
#   Redeploys views/resellers.ejs (renders the hero + responsive grid fix). Idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-resellershero-$TS"; cd "$GSZ"
AD=routes/admin.js; PG=routes/pages.js; PUB=views/resellers.ejs
mkdir -p "$BK/routes" "$BK/views"
cp "$GSZ/$AD" "$BK/$AD"; cp "$GSZ/$PG" "$BK/$PG"; cp "$GSZ/$PUB" "$BK/$PUB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AD" "$GSZ/$AD"; cp "$BK/$PG" "$GSZ/$PG"; cp "$BK/$PUB" "$GSZ/$PUB"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> redeploy public page (hero + responsive grid) + patch admin/pages"
cp -f "$SRC/resellers_page.ejs" "$GSZ/$PUB"
node "$SRC/patch_resellers_hero.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/$AD" && echo "   admin.js ok"
node --check "$GSZ/$PG" && echo "   pages.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$PUB','utf8'),{filename:'$GSZ/$PUB'});console.log('   resellers.ejs compiles');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done
curl -s -o /dev/null -w '   /resellers -> %{http_code}\n' http://127.0.0.1:3900/resellers || true
echo "DONE — Admin → Branding now has a 'Reseller Panels' banner slot (desktop + mobile). Upload there and it shows as the /resellers hero. Grid is phone/desktop responsive."
