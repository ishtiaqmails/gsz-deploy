#!/usr/bin/env bash
# stepSafeNext.sh — close the backslash open-redirect in safeNext(). The old check let "/\evil.com"
# through (browsers normalise \ to /, making it protocol-relative). New check: /^\/[^\/\\]/ — must
# start with a single / followed by a non-slash, non-backslash char. Legit paths unchanged.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
AC="$GSZ/routes/account.js"; TS=$(date +%s)
cp -f "$AC" "$AC.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$AC.xbak.$TS" "$AC"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> harden safeNext()"
export AC
node <<'NODE'
const fs=require('fs'); const AC=process.env.AC; let s=fs.readFileSync(AC,'utf8');
const old="return (n.charAt(0) === '/' && n.charAt(1) !== '/') ? n : '/account';";
const neu="return (/^\\/[^\\/\\\\]/.test(n)) ? n : '/account';";
if(s.indexOf("/^\\/[^")>=0){ console.log('   already hardened'); process.exit(0); }
if(s.split(old).length-1!==1) throw new Error('safeNext anchor not unique ('+(s.split(old).length-1)+')');
s=s.split(old).join(neu); fs.writeFileSync(AC,s); console.log('   safeNext now rejects // and backslash redirects');
NODE

echo "==> check + restart + health"
node --check "$AC"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — open-redirect closed. Backup: $AC.xbak.$TS"
