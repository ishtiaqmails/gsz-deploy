#!/usr/bin/env bash
# stepCountryLogin.sh — capture geo country at login into customers.last_country (ASCII-only, try/catch safe)
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=routes/account.js
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_pl.js; exit 1; }
trap restore ERR
nchk(){ local f="$1" i; for i in 1 2 3 4 5; do if node --check "$f" 2>/dev/null; then return 0; fi; sleep 1; done; echo "  node --check kept failing on $f; suspect lines:"; grep -nE "last_login|last_country|_cc" "$f" | cat -A | head -8; return 1; }

echo "==> patching login handler (capture cf-ipcountry)"
cat > .gszm_pl.js <<'JS'
var fs = require('fs');
var f = 'routes/account.js';
var s = fs.readFileSync(f, 'utf8');
var a = "await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]);";
var b = "try{ var _cc=String(req.headers['cf-ipcountry']||'').toUpperCase().replace(/[^A-Z]/g,''); if(_cc.length===2 && _cc!=='XX' && _cc!=='T1'){ await pool.query('UPDATE customers SET last_login=now(), last_country=$2, last_country_at=now() WHERE id=$1', [c.id, _cc]); } else { await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]); } }catch(_e){ try{ await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]); }catch(_e2){} }";
var n = s.split(a).length - 1;
if (n !== 1) {
  console.log('  ANCHOR MATCH x' + n + ' — candidate lines:');
  s.split('\n').forEach(function(l, i){ if (l.indexOf('last_login') >= 0) console.log('   ' + (i+1) + ': ' + l.trim()); });
  process.exit(2);
}
fs.writeFileSync(f, s.split(a).join(b));
console.log('  login capture: ok');
process.exit(0);
JS
node .gszm_pl.js

echo "==> validating"
nchk routes/account.js
rm -f .gszm_pl.js
echo "   check passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Real country now captured on each customer sign-in."
