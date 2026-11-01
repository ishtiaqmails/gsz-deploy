#!/usr/bin/env bash
# stepWaMobile.sh — WhatsApp Control Center: fit on phone (cards shrink to viewport) +
# near-instant updates (activity polls every 2s, connection every 3s).
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.wamobbak.$TS"; mkdir -p "$BAKDIR"
WV="$GSZ/views/admin/wabot.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/wabot.ejs" ] && cp -f "$BAKDIR/wabot.ejs" "$WV"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$WV" "$BAKDIR/wabot.ejs"
echo "==> deploy"; cp -f "$DEPLOY/views/admin/wabot.ejs" "$WV"
echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$WV"'","utf8"),{filename:"'"$WV"'"});console.log("   OK")'
echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — /admin/wabot now fits phone + updates every 2s. Backups: $BAKDIR"
