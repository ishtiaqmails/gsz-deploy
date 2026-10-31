#!/usr/bin/env bash
# stepAdminGeoFix.sh — tiny: make the admin page-list table scroll-safe so the
# Publish/Unpublish buttons are never cut off on narrower screens. View-only change.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s); BAK="$GSZ/views/admin/geo.ejs.bak.$TS"
restore(){ echo "!! failed — rolling back"; [ -f "$BAK" ] && cp -f "$BAK" "$GSZ/views/admin/geo.ejs"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> update views/admin/geo.ejs"
cp -f "$GSZ/views/admin/geo.ejs" "$BAK"
cp -f "$DEPLOY/views/admin/geo.ejs" "$GSZ/views/admin/geo.ejs"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GSZ"'/views/admin/geo.ejs","utf8"),{filename:"x"});console.log("   compiles OK")'
echo "==> restart"; pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed"; false; }
trap - ERR
echo "   healthy. Reload /admin/geo — the table now scrolls instead of clipping. Backup: $BAK"
