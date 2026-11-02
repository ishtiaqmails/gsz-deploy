#!/usr/bin/env bash
# stepCookieSecure.sh — add secure:true to the session cookie (HTTPS-only). Safe behind Cloudflare
# because 'trust proxy' is set and CF sends X-Forwarded-Proto: https. LOW urgency (HSTS already
# forces HTTPS). TEST AFTER DEPLOY: log out and back in — if sign-in breaks, roll back from backup.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
SV="$GSZ/server.js"; TS=$(date +%s)
cp -f "$SV" "$SV.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$SV.xbak.$TS" "$SV"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> add secure:true to the session cookie"
export SV
node <<'NODE'
const fs=require('fs'); const SV=process.env.SV; let s=fs.readFileSync(SV,'utf8');
const anchor="cookie: { maxAge: 30 * 24 * 60 * 60 * 1000, httpOnly: true, sameSite: 'lax' }";
if(s.indexOf("sameSite: 'lax', secure: true")>=0){ console.log('   already set'); process.exit(0); }
if(s.split(anchor).length-1!==1) throw new Error('cookie anchor not unique ('+(s.split(anchor).length-1)+')');
s=s.split(anchor).join("cookie: { maxAge: 30 * 24 * 60 * 60 * 1000, httpOnly: true, sameSite: 'lax', secure: true }");
fs.writeFileSync(SV,s); console.log('   secure:true added');
NODE

echo "==> check + restart + health"
node --check "$SV"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — session cookie is now HTTPS-only. NOW TEST: log out + back in. If login breaks: cp $SV.xbak.$TS $SV && pm2 restart $APP"
