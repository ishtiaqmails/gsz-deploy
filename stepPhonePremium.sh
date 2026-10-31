#!/usr/bin/env bash
# stepPhonePremium.sh — premium country picker + always-fresh auth pages.
#   views/partials/phone_field.ejs : NEW shared component — custom searchable country picker
#        (country name + dial code, keyboard-friendly, no flags), live +code badge, number input.
#        Fully responsive. Used by BOTH signup and login (one source, no duplicated code).
#   views/account/signup.ejs , login.ejs : use the shared partial (old inline selects removed).
#   routes/account.js : Cache-Control: no-store on the /login and /signup GET renders so every
#        customer always gets the latest page (no stale cached version).
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.phonebak.$TS"; mkdir -p "$BAKDIR"
PF="$GSZ/views/partials/phone_field.ejs"
SU="$GSZ/views/account/signup.ejs"; LG="$GSZ/views/account/login.ejs"; AC="$GSZ/routes/account.js"
restore(){ echo "!! failed — rolling back"; \
  [ -f "$BAKDIR/signup.ejs" ] && cp -f "$BAKDIR/signup.ejs" "$SU"; \
  [ -f "$BAKDIR/login.ejs" ]  && cp -f "$BAKDIR/login.ejs"  "$LG"; \
  [ -f "$BAKDIR/account.js" ] && cp -f "$BAKDIR/account.js" "$AC"; \
  [ -f "$BAKDIR/phone_field.ejs" ] && cp -f "$BAKDIR/phone_field.ejs" "$PF" || rm -f "$PF"; \
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$SU" "$BAKDIR/signup.ejs"; cp -f "$LG" "$BAKDIR/login.ejs"; cp -f "$AC" "$BAKDIR/account.js"
[ -f "$PF" ] && cp -f "$PF" "$BAKDIR/phone_field.ejs" || true

echo "==> deploy partial + views"
mkdir -p "$GSZ/views/partials"
cp -f "$DEPLOY/views/partials/phone_field.ejs" "$PF"
cp -f "$DEPLOY/views/account/signup.ejs" "$SU"
cp -f "$DEPLOY/views/account/login.ejs" "$LG"

echo "==> patch account.js — no-store on /login + /signup GET renders"
export AC
node <<'NODE'
const fs=require('fs'); const F=process.env.AC;
let s=fs.readFileSync(F,'utf8');
function patch(anchor, repl, label){
  if(s.indexOf(repl)>=0){ console.log('   - '+label+': already no-store'); return; }
  const n=s.split(anchor).length-1;
  if(n!==1) throw new Error(label+' anchor not unique/found ('+n+')');
  s=s.split(anchor).join(repl);
  console.log('   - '+label+': no-store added ✓');
}
patch("res.render('account/login', Object.assign(await shell()",
      "res.set('Cache-Control','no-store, max-age=0'); res.render('account/login', Object.assign(await shell()",
      'GET /login');
patch("res.render('account/signup', Object.assign(await shell()",
      "res.set('Cache-Control','no-store, max-age=0'); res.render('account/signup', Object.assign(await shell()",
      'GET /signup');
fs.writeFileSync(F,s);
NODE

echo "==> compile checks"
node --check "$AC"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");["'"$SU"'","'"$LG"'"].forEach(function(f){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});});console.log("   signup + login compile OK (partial resolves)")'

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE — reload /signup and /login (hard refresh once)."
echo "  • Premium searchable picker: country name + dial code, type to filter, keyboard arrows + Enter"
echo "  • Auto-detected country; live +code on the number; fits phone & desktop"
echo "  • no-store headers: every customer now gets the latest page, no stale cache"
echo "Backups: $BAKDIR"
