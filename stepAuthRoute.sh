#!/usr/bin/env bash
# stepAuthRoute.sh — route EVERY /login and /signup link click to the real Hub modal
# (window.__gszAuth) instead of store_bottom's injected .authm modal, whose scripts never run
# (dead toggle/picker). One fix makes every sign-in / create-account open the same updated pop-up.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.authroutebak.$TS"; mkdir -p "$BAKDIR"
SB="$GSZ/views/partials/store_bottom.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/store_bottom.ejs" ] && cp -f "$BAKDIR/store_bottom.ejs" "$SB"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$SB" "$BAKDIR/store_bottom.ejs"

echo "==> route /login /signup clicks to the Hub modal"
export SB
node <<'NODE'
const fs=require('fs'); const F=process.env.SB;
let s=fs.readFileSync(F,'utf8');
if(s.indexOf("window.__gszAuth(u.pathname")>=0){ console.log('   already routed'); process.exit(0); }
const anchor="if(u.pathname==='/login'||u.pathname==='/signup'){ e.preventDefault(); load(u.pathname+u.search); }";
const n=s.split(anchor).length-1;
if(n!==1) throw new Error('interceptor anchor not unique/found ('+n+')');
const neu="if(u.pathname==='/login'||u.pathname==='/signup'){ e.preventDefault(); if(typeof window.__gszAuth==='function'){ window.__gszAuth(u.pathname==='/signup'?'signup':'signin'); } else { load(u.pathname+u.search); } }";
s=s.split(anchor).join(neu);
fs.writeFileSync(F,s); console.log('   routed to __gszAuth');
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$SB"'","utf8"),{filename:"'"$SB"'"});console.log("   compiles OK")'
echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — all /login + /signup links now open the updated Hub pop-up. Backups: $BAKDIR"
