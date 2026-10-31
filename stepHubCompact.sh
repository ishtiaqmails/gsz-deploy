#!/usr/bin/env bash
# stepHubCompact.sh — tighten the Hub auth forms (field spacing, input padding, body padding)
# so Create Account fits with NO scroll even on a short viewport.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.compactbak.$TS"; mkdir -p "$BAKDIR"
HM="$GSZ/views/partials/hub_model.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/hub_model.ejs" ] && cp -f "$BAKDIR/hub_model.ejs" "$HM"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$HM" "$BAKDIR/hub_model.ejs"

echo "==> compact auth-mode CSS"
export HM
node <<'NODE'
const fs=require('fs'); const F=process.env.HM;
let s=fs.readFileSync(F,'utf8');
const anchor=".cthm-card.cthm-authmode .cthm-f{margin-bottom:10px}";
const n=s.split(anchor).length-1;
if(n!==1) throw new Error('authmode css anchor not found ('+n+')');
const neu=".cthm-card.cthm-authmode .cthm-f{margin-bottom:7px}\n"
 +"   .cthm-card.cthm-authmode .cthm-f label{margin-bottom:3px}\n"
 +"   .cthm-card.cthm-authmode .cthm-body{padding:12px 22px 16px}\n"
 +"   .cthm-card.cthm-authmode input[type=text],.cthm-card.cthm-authmode input[type=email],.cthm-card.cthm-authmode input[type=password],.cthm-card.cthm-authmode input[type=tel]{padding:9px 12px}\n"
 +"   .cthm-card.cthm-authmode .pf-cc,.cthm-card.cthm-authmode .pf-numin{padding-top:9px;padding-bottom:9px}";
s=s.split(anchor).join(neu);
fs.writeFileSync(F,s); console.log('   compact css applied');
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$HM"'","utf8"),{filename:"'"$HM"'"});console.log("   compiles OK")'
echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — auth forms compacted. Backups: $BAKDIR"
