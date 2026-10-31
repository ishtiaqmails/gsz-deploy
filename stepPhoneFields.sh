#!/usr/bin/env bash
# stepPhoneFields.sh — clearer phone/login fields (no route changes).
#   views/account/signup.ejs : country code AUTO-DETECTED from visitor (geoCountry) instead of
#                              hard-coded PK; full-width flag picker they can still change; live
#                              +code badge on the number so the format is obvious.
#   views/account/login.ejs  : Email / Phone toggle so customers pick how they sign in; phone side
#                              gets the same country picker. Backend already reads email+wa_country.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.phonebak.$TS"; mkdir -p "$BAKDIR"
SU="$GSZ/views/account/signup.ejs"; LG="$GSZ/views/account/login.ejs"
restore(){ echo "!! failed — rolling back"; \
  [ -f "$BAKDIR/signup.ejs" ] && cp -f "$BAKDIR/signup.ejs" "$SU"; \
  [ -f "$BAKDIR/login.ejs" ]  && cp -f "$BAKDIR/login.ejs"  "$LG"; \
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$SU" "$BAKDIR/signup.ejs"; cp -f "$LG" "$BAKDIR/login.ejs"

echo "==> deploy views"
cp -f "$DEPLOY/views/account/signup.ejs" "$SU"
cp -f "$DEPLOY/views/account/login.ejs" "$LG"

echo "==> ejs compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");["'"$SU"'","'"$LG"'"].forEach(function(f){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});});console.log("   both compile OK")'

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE — check https://galaxyzayron.store/signup and /login"
echo "  • Signup: country auto-detected from the visitor; full flag picker; live +code on the number"
echo "  • Login:  Email / Phone toggle; phone side has the country picker"
echo "Backups: $BAKDIR"
