#!/usr/bin/env bash
# stepBuyAuthFix2.sh — corrects stepBuyAuthFix.sh, which matched a .bak backup instead of the
# live view. This targets only real *.ejs files, and reverts the stray edit the first run made
# to the backup copy.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
ANCHOR="window.__gszAuth=function(mode){ if(!modal.classList.contains('on')){"

echo "==> revert the stray edit to the .bak copy (cleanup)"
BB="$GSZ/views/partials/customer_tools.ejs.bak.1791663727"
XB=$(ls "$BB".xbak.* 2>/dev/null | head -1 || true)
if [ -n "${XB:-}" ] && [ -f "$XB" ]; then cp -f "$XB" "$BB" && rm -f "$XB" && echo "   reverted $BB and removed stray backup"; else echo "   (nothing to revert)"; fi

echo "==> locate the LIVE view (real .ejs only, no .bak)"
FILE=$(grep -rlF "$ANCHOR" "$GSZ/views" --include="*.ejs" 2>/dev/null | grep -vE '\.(bak|xbak)' | head -1)
[ -n "$FILE" ] || { echo "could not locate the live __gszAuth .ejs in $GSZ/views"; exit 1; }
echo "   target: $FILE"
TS=$(date +%s); cp -f "$FILE" "$FILE.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$FILE.xbak.$TS" "$FILE"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> patch __gszAuth (close Buy-now modal on open)"
export FILE
node <<'NODE'
const fs=require('fs'); const FILE=process.env.FILE; let s=fs.readFileSync(FILE,'utf8');
const anchor="window.__gszAuth=function(mode){ if(!modal.classList.contains('on')){";
if(s.indexOf("querySelector('.gbuy.on')")>=0){ console.log('   already fixed'); process.exit(0); }
if(s.split(anchor).length-1!==1) throw new Error('anchor not unique (found '+(s.split(anchor).length-1)+')');
const neu="window.__gszAuth=function(mode){ try{var _gb=document.querySelector('.gbuy.on');if(_gb)_gb.classList.remove('on');}catch(e){} if(!modal.classList.contains('on')){";
s=s.split(anchor).join(neu);
fs.writeFileSync(FILE,s); console.log('   patched live view');
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync(process.env.FILE,"utf8"),{filename:process.env.FILE});console.log("   view compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — live Buy-now auth gate fixed. Backup: $FILE.xbak.$TS"
