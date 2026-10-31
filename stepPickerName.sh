#!/usr/bin/env bash
# stepPickerName.sh — stop the country button from shrinking so the full name ("Pakistan +92")
# shows when there's room; it only truncates past 56% of the row on very narrow screens.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.pnamebak.$TS"; mkdir -p "$BAKDIR"
PFA="$GSZ/views/partials/phone_field_assets.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/phone_field_assets.ejs" ] && cp -f "$BAKDIR/phone_field_assets.ejs" "$PFA"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$PFA" "$BAKDIR/phone_field_assets.ejs"
echo "==> deploy"; cp -f "$DEPLOY/views/partials/phone_field_assets.ejs" "$PFA"
echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$PFA"'","utf8"),{filename:"'"$PFA"'"});console.log("   OK")'
echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE. Backups: $BAKDIR"
