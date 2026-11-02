#!/usr/bin/env bash
# stepSecHeaders.sh — add a SAFE baseline CSP + Permissions-Policy. The CSP intentionally sets NO
# default-src/script-src, so inline scripts, the FB pixel and Cloudflare keep working untouched;
# it only blocks plugins (object/embed), <base> injection, framing, and upgrades http subresources.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
SV="$GSZ/server.js"; TS=$(date +%s)
[ -f "$SV" ] || { echo "no server.js"; exit 1; }
cp -f "$SV" "$SV.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$SV.xbak.$TS" "$SV"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> add CSP + Permissions-Policy after helmet"
export SV
node <<'NODE'
const fs=require('fs'); const SV=process.env.SV; let s=fs.readFileSync(SV,'utf8');
if(s.indexOf("Permissions-Policy")>=0){ console.log('   already added'); process.exit(0); }
const anchor="app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));";
if(s.split(anchor).length-1!==1) throw new Error('helmet anchor not unique ('+(s.split(anchor).length-1)+')');
const ins=anchor+"\n"+
"  app.use(function (req, res, next) {\n"+
"    res.setHeader('Content-Security-Policy', \"object-src 'none'; base-uri 'self'; frame-ancestors 'self'; upgrade-insecure-requests\");\n"+
"    res.setHeader('Permissions-Policy', 'geolocation=(), camera=(), microphone=(), usb=()');\n"+
"    next();\n"+
"  });";
s=s.split(anchor).join(ins);
fs.writeFileSync(SV,s); console.log('   CSP + Permissions-Policy middleware added');
NODE

echo "==> check + restart + health"
node --check "$SV"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — safe CSP + Permissions-Policy live. Backup: $SV.xbak.$TS"
