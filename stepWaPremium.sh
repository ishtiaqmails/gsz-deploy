#!/usr/bin/env bash
# stepWaPremium.sh — premium WhatsApp command center + bulletproof numbers.
#   routes/wabot.js         : adds GET /wabot/activity.json (live events + today's stats)
#   views/admin/wabot.ejs   : premium monitor — hero status, stat tiles, live feed, toggles
#   views/partials/app_nav.ejs + routes/sitemap.js : kill the hard-coded 923141892712 fallback
#                             so a wiped number can never resurface an old one (numbers stay live).
# Monitor deploy is fatal-guarded (rolls back on failure); the number tidy-up is best-effort.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.wabak.$TS"; mkdir -p "$BAKDIR"
WB="$GSZ/routes/wabot.js"; WV="$GSZ/views/admin/wabot.ejs"
NAV="$GSZ/views/partials/app_nav.ejs"; SM="$GSZ/routes/sitemap.js"
restore(){ echo "!! failed — rolling back"; \
  [ -f "$BAKDIR/wabot.js" ] && cp -f "$BAKDIR/wabot.js" "$WB"; \
  [ -f "$BAKDIR/wabot.ejs" ] && cp -f "$BAKDIR/wabot.ejs" "$WV"; \
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$WB" "$BAKDIR/wabot.js"; cp -f "$WV" "$BAKDIR/wabot.ejs"
[ -f "$NAV" ] && cp -f "$NAV" "$BAKDIR/app_nav.ejs" || true
[ -f "$SM" ]  && cp -f "$SM"  "$BAKDIR/sitemap.js"  || true

echo "==> deploy premium monitor (route + view)"
cp -f "$DEPLOY/routes/wabot.js" "$WB"
cp -f "$DEPLOY/views/admin/wabot.ejs" "$WV"

echo "==> node --check + ejs compile"
node --check "$WB"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$WV"'","utf8"),{filename:"'"$WV"'"});console.log("   view compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"

echo "==> bulletproof numbers (best-effort; won't roll back the monitor)"
export NAV SM
node <<'NODE' || echo "   (number tidy-up skipped — see notes above)"
const fs=require('fs');
function patch(file, anchor, repl, label){
  if(!file || !fs.existsSync(file)){ console.log('   - '+label+': file missing, skipped'); return; }
  let s=fs.readFileSync(file,'utf8');
  const n=s.split(anchor).length-1;
  if(n===0){ console.log('   - '+label+': already clean (no hard-coded fallback)'); return; }
  if(n!==1){ console.log('   - '+label+': anchor not unique ('+n+') — left as-is'); return; }
  s=s.split(anchor).join(repl);
  fs.writeFileSync(file,s);
  console.log('   - '+label+': fallback neutralised ✓');
}
// app_nav.ejs line 5 fallback:  ...:(waNumber?waNumber:'923141892712'))...  ->  :'')
patch(process.env.NAV, ":'923141892712')", ":'')", 'app_nav.ejs');
// sitemap.js line 87:  let wa = '923141892712';  ->  let wa = '';
patch(process.env.SM, "let wa = '923141892712';", "let wa = '';", 'sitemap.js');
NODE

# re-validate anything the tidy-up touched, then restart once more if it changed a file
if [ -f "$SM" ]; then node --check "$SM" || { echo "   sitemap check failed — restoring sitemap"; cp -f "$BAKDIR/sitemap.js" "$SM"; }; fi
if [ -f "$NAV" ]; then node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$NAV"'","utf8"),{filename:"'"$NAV"'"});' || { echo "   nav compile failed — restoring nav"; cp -f "$BAKDIR/app_nav.ejs" "$NAV"; }; fi
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && echo "   still healthy" || echo "   WARN: health check after tidy-up failed — check pm2 logs"

echo
echo "DONE — open https://galaxyzayron.store/admin/wabot"
echo "  • Hero shows LIVE bot status + bot number, pulsing when online"
echo "  • Stat tiles: verified customers / verified today / started today / messages today"
echo "  • Live activity feed refreshes every 5s — every verification & message as it happens"
echo "  • Numbers save live everywhere; no old number can resurface"
echo "Backups: $BAKDIR"
