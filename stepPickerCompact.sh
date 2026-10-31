#!/usr/bin/env bash
# stepPickerCompact.sh — make the country picker a single compact row
# ([ country +code v | number ]) everywhere. Only the shared component changes; the Hub
# modal + pages pick it up automatically (modal builds via __pfMarkup). Removes the extra
# row that was causing the pop-up to scroll.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.pickerbak.$TS"; mkdir -p "$BAKDIR"
PFA="$GSZ/views/partials/phone_field_assets.ejs"; PF="$GSZ/views/partials/phone_field.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/phone_field_assets.ejs" ] && cp -f "$BAKDIR/phone_field_assets.ejs" "$PFA"; [ -f "$BAKDIR/phone_field.ejs" ] && cp -f "$BAKDIR/phone_field.ejs" "$PF"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$PFA" "$BAKDIR/phone_field_assets.ejs"; cp -f "$PF" "$BAKDIR/phone_field.ejs"

echo "==> deploy compact picker"
cp -f "$DEPLOY/views/partials/phone_field_assets.ejs" "$PFA"
cp -f "$DEPLOY/views/partials/phone_field.ejs" "$PF"

echo "==> compile checks"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");["'"$PFA"'","'"$PF"'","'"$GSZ"'/views/partials/hub_model.ejs","'"$GSZ"'/views/account/signup.ejs","'"$GSZ"'/views/account/login.ejs"].forEach(function(f){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});});console.log("   all compile OK")'

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — picker is now one compact row. Backups: $BAKDIR"
