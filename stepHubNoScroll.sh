#!/usr/bin/env bash
# stepHubNoScroll.sh — make the Galaxy Hub auth views fit with NO scroll.
# When a sign-in / create-account / forgot / reset form is shown, hide the tab bar + subtitle
# (the chrome that was eating the height), so the form uses the full card. After login the
# page reloads and the tabs come back. Pure add: a CSS rule set + an `authm` class toggled
# from renderFoot (which already knows authScreen) + cleared when a real tab view opens.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.noscrollbak.$TS"; mkdir -p "$BAKDIR"
HM="$GSZ/views/partials/hub_model.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/hub_model.ejs" ] && cp -f "$BAKDIR/hub_model.ejs" "$HM"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$HM" "$BAKDIR/hub_model.ejs"

echo "==> patch hub_model.ejs"
export HM
node <<'NODE'
const fs=require('fs'); const F=process.env.HM;
let s=fs.readFileSync(F,'utf8');
function once(anchor, neu, label){
  const n=s.split(anchor).length-1;
  if(n!==1) throw new Error(label+': expected 1, got '+n);
  s=s.split(anchor).join(neu);
  console.log('   - '+label+': ok');
}
// a) CSS: auth-mode hides tab chrome so forms fit
if(s.indexOf('.cthm-card.authm')>=0){ console.log('   - css: already present'); }
else {
  once('.cthm-foot:empty{display:none}',
       '.cthm-foot:empty{display:none}\n   .cthm-card.authm .cthm-tabs{display:none}\n   .cthm-card.authm .cthm-head{padding:20px 22px 8px}\n   .cthm-card.authm .cthm-head p{display:none}\n   .cthm-card.authm .cthm-f{margin-bottom:10px}',
       'css auth-mode');
}
// b) renderFoot toggles the authm class from authScreen (one choke point)
once('function renderFoot(){ var f=document.getElementById(\'cthmFoot\'); if(!f) return;',
     'function renderFoot(){ var f=document.getElementById(\'cthmFoot\'); if(!f) return; var _cc=document.querySelector(\'.cthm-card\'); if(_cc) _cc.classList.toggle(\'authm\', !!authScreen);',
     'renderFoot authm toggle');
// c) opening a real tab view clears authm (safety for reopen)
once('function open(tab){ modal.classList.add(\'on\'); window.__gszScrollLock.lock(); setTab(tab||\'purchases\'); }',
     'function open(tab){ var _cc=document.querySelector(\'.cthm-card\'); if(_cc) _cc.classList.remove(\'authm\'); modal.classList.add(\'on\'); window.__gszScrollLock.lock(); setTab(tab||\'purchases\'); }',
     'open() clear authm');
fs.writeFileSync(F,s);
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$HM"'","utf8"),{filename:"'"$HM"'"});console.log("   hub_model compiles OK")'

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — auth views now hide the tab bar so they fit with no scroll. Backups: $BAKDIR"
