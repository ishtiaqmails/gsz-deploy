#!/usr/bin/env bash
# ============================================================
#  STEP 36: order-toss — show real price, drop "X min ago", keep spacing
#  In-place patch of public/js/app.js showToss(); bumps app.js cache version.
#  Auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/public/js/app.js" ] || { echo "ABORT: app.js not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
TS=$(date +%s); BK="$APP/.bak-step36-$TS"; mkdir -p "$BK"
cp public/js/app.js "$BK/app.js"
[ -f views/partials/store_bottom.ejs ] && cp views/partials/store_bottom.ejs "$BK/store_bottom.ejs" || true
restore(){ echo "!! ROLLBACK"; cp "$BK/app.js" public/js/app.js 2>/dev/null||true; [ -f "$BK/store_bottom.ejs" ] && cp "$BK/store_bottom.ejs" views/partials/store_bottom.ejs 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR
echo "== Step 36 (order-toss: price, no timestamp) =="

node <<'NODE'
const fs=require('fs'), f='public/js/app.js';
let s=fs.readFileSync(f,'utf8');
const oldLine = "'<span class=\"tb\"><b>'+p.name+'</b><span>Someone just ordered · '+mins+' min ago</span></span>'+";
const newLine = "'<span class=\"tb\"><b>'+p.name+'</b><span>Someone just ordered'+(p.from>0?(' · '+money(p.from)):'')+'</span></span>'+";
let n = s.split(oldLine).length-1;
if(n!==1){ console.error('ABORT: toss line match count='+n); process.exit(1); }
s = s.replace(oldLine, newLine);
// drop the now-unused mins variable
const minsDecl = "var mins=2+Math.floor(Math.random()*28);";
if(s.indexOf(minsDecl)>=0){ s = s.replace(minsDecl, "/* ordered-time removed */"); }
fs.writeFileSync(f,s);
console.log('[ok] showToss patched');
NODE

node --check public/js/app.js && echo "[ok] app.js syntax" || { echo "ABORT syntax"; exit 1; }

# bump app.js cache version so browsers fetch the new file
SB=views/partials/store_bottom.ejs
if [ -f "$SB" ] && grep -q "app.js?v=" "$SB"; then
  cur=$(grep -o "app.js?v=[0-9]*" "$SB" | head -1 | grep -o "[0-9]*")
  new=$((cur+1))
  sed -i "s/app.js?v=[0-9]*/app.js?v=$new/g" "$SB"
  echo "[ok] app.js cache version -> $new"
else
  echo "(no app.js?v= found in store_bottom — hard-refresh the page to see it)"
fi

pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
grep -q "</html>" <<< "$(curl -fsS http://127.0.0.1:${PORT:-3900}/ 2>/dev/null || true)" && echo "[ok] site responding" || echo "!! health soft-fail"
trap - ERR
echo
echo "==================== STEP 36 DONE ===================="
echo " Order-toss now shows the real price (e.g. 'Someone just ordered · Rs 300'),"
echo " no more 'X min ago'. Toasts stay ~3-6 min apart."
echo "====================================================="
