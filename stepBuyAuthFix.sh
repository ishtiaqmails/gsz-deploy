#!/usr/bin/env bash
# stepBuyAuthFix.sh — fix: tapping "Sign in"/"Create account" inside the Buy-now gate opened the
# auth modal (cthm, z-index 600) BEHIND the Buy-now modal (gbuy, z-index 650), whose scrim then
# ate every tap — the customer saw the auth form switching tabs but could not touch it.
# Fix: when the auth modal opens, close any open Buy-now modal first. One line, at the single
# choke point __gszAuth, so it covers every way the auth modal is opened.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
ANCHOR="window.__gszAuth=function(mode){ if(!modal.classList.contains('on')){"
FILE=$(grep -rlF "$ANCHOR" "$GSZ/views" 2>/dev/null | head -1)
[ -n "$FILE" ] || { echo "could not locate the __gszAuth source in $GSZ/views"; exit 1; }
echo "==> target: $FILE"
TS=$(date +%s); cp -f "$FILE" "$FILE.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$FILE.xbak.$TS" "$FILE"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> patch __gszAuth (close Buy-now modal on open)"
export FILE
node <<'NODE'
const fs=require('fs'); const FILE=process.env.FILE; let s=fs.readFileSync(FILE,'utf8');
const anchor="window.__gszAuth=function(mode){ if(!modal.classList.contains('on')){";
if(s.indexOf("querySelector('.gbuy.on')")>=0 && s.indexOf('__gszAuth')>=0){ console.log('   already fixed'); process.exit(0); }
if(s.split(anchor).length-1!==1) throw new Error('anchor not unique (found '+(s.split(anchor).length-1)+')');
const neu="window.__gszAuth=function(mode){ try{var _gb=document.querySelector('.gbuy.on');if(_gb)_gb.classList.remove('on');}catch(e){} if(!modal.classList.contains('on')){";
s=s.split(anchor).join(neu);
fs.writeFileSync(FILE,s); console.log('   patched: Buy-now modal now closes when the auth modal opens');
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync(process.env.FILE,"utf8"),{filename:process.env.FILE});console.log("   view compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — Buy now -> Sign in now opens a tappable auth modal. Backup: $FILE.xbak.$TS"
