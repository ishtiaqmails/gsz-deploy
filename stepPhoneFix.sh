#!/usr/bin/env bash
# stepPhoneFix.sh — fix the leaked-global guard that disabled the picker CSS/JS after the
# first render. phone_field.ejs now always emits its <style>+<script> (each page includes it
# once, so no dedup needed). This restores the premium picker for ALL requests, not just the
# first one after a restart.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.phonefixbak.$TS"; mkdir -p "$BAKDIR"
PF="$GSZ/views/partials/phone_field.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/phone_field.ejs" ] && cp -f "$BAKDIR/phone_field.ejs" "$PF"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$PF" "$BAKDIR/phone_field.ejs"

echo "==> deploy fixed partial"
cp -f "$DEPLOY/views/partials/phone_field.ejs" "$PF"

echo "==> guard removed?"
if grep -q "_pfAssets" "$PF"; then echo "   STILL has _pfAssets — aborting"; false; else echo "   clean ✓"; fi

echo "==> compile check (signup pulls the partial)"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GSZ"'/views/account/signup.ejs","utf8"),{filename:"'"$GSZ"'/views/account/signup.ejs"});console.log("   compiles OK")'

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE — picker now styled on EVERY request. Hard-refresh /signup and /login to confirm."
echo "Backups: $BAKDIR"
