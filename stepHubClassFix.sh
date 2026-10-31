#!/usr/bin/env bash
# stepHubClassFix.sh — fix class-name collision: the Hub auth-mode class `authm` clashed with
# store_bottom's global `.authm` (display:none), hiding the whole card. Rename to `cthm-authmode`.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.classfixbak.$TS"; mkdir -p "$BAKDIR"
HM="$GSZ/views/partials/hub_model.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/hub_model.ejs" ] && cp -f "$BAKDIR/hub_model.ejs" "$HM"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"; cp -f "$HM" "$BAKDIR/hub_model.ejs"

echo "==> rename authm -> cthm-authmode"
export HM
node <<'NODE'
const fs=require('fs'); const F=process.env.HM;
let s=fs.readFileSync(F,'utf8');
s=s.split(".cthm-card.authm ").join(".cthm-card.cthm-authmode ");
s=s.split("toggle('authm',").join("toggle('cthm-authmode',");
s=s.split("remove('authm')").join("remove('cthm-authmode')");
if(s.indexOf(".cthm-card.authm ")>=0 || s.indexOf("toggle('authm',")>=0 || s.indexOf("remove('authm')")>=0) throw new Error('leftover authm refs');
if(s.indexOf(".cthm-card.cthm-authmode ")<0) throw new Error('rename did not apply');
fs.writeFileSync(F,s); console.log('   renamed ok');
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$HM"'","utf8"),{filename:"'"$HM"'"});console.log("   compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — Hub auth-mode class renamed; card shows again + tabs hidden with no scroll. Backups: $BAKDIR"
