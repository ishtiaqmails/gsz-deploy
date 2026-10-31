#!/usr/bin/env bash
# stepLoginCountries.sh — fix: the login view's country picker was empty because the
# login route never passed the country list (only signup did). Add countries:phone.countries()
# to both /login renders (GET + POST re-render). phone is already required in account.js.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.acctbak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/account.js"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/account.js" ] && cp -f "$BAKDIR/account.js" "$AC"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$AC" "$BAKDIR/account.js"

echo "==> patch /login renders to pass countries"
export AC
node <<'NODE'
const fs=require('fs'); const F=process.env.AC;
let s=fs.readFileSync(F,'utf8');
function patch(anchor, repl, label){
  const n=s.split(anchor).length-1;
  if(s.indexOf(repl)>=0){ console.log('   - '+label+': already has countries'); return; }
  if(n!==1) throw new Error(label+' anchor not unique/found ('+n+')');
  s=s.split(anchor).join(repl);
  console.log('   - '+label+': countries added ✓');
}
// GET /login
patch("{ title: 'Sign in', error: null, email: '', next: req.query.next || '' }",
      "{ title: 'Sign in', error: null, email: '', next: req.query.next || '', countries: phone.countries() }",
      'GET /login');
// POST /login re-render
patch("{ title: 'Sign in', error: err, email: idf, next }",
      "{ title: 'Sign in', error: err, email: idf, next, countries: phone.countries() }",
      'POST /login');
fs.writeFileSync(F,s);
NODE

echo "==> node --check"
node --check "$AC"

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE — reload https://galaxyzayron.store/login and click Phone; the country picker now fills."
echo "Backups: $BAKDIR"
