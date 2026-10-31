#!/usr/bin/env bash
# stepHubSignup.sh — give the Galaxy Hub pop-up's CREATE ACCOUNT the same premium country
# picker as the /signup page, reusing ONE shared component.
#   views/partials/phone_field_assets.ejs : NEW — shared picker CSS/JS (+ __pfMarkup, __pfEnsureCC)
#   views/partials/phone_field.ejs         : now uses the shared assets (pages unchanged in behaviour)
#   routes/account.js                       : + GET /api/countries (lets the modal load the list anywhere)
#   views/partials/hub_model.ejs            : signup form uses the picker (country name + dial code)
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.hubbak.$TS"; mkdir -p "$BAKDIR"
PFA="$GSZ/views/partials/phone_field_assets.ejs"
PF="$GSZ/views/partials/phone_field.ejs"
AC="$GSZ/routes/account.js"
HM="$GSZ/views/partials/hub_model.ejs"
restore(){ echo "!! failed — rolling back"; \
  [ -f "$BAKDIR/phone_field.ejs" ] && cp -f "$BAKDIR/phone_field.ejs" "$PF"; \
  [ -f "$BAKDIR/account.js" ] && cp -f "$BAKDIR/account.js" "$AC"; \
  [ -f "$BAKDIR/hub_model.ejs" ] && cp -f "$BAKDIR/hub_model.ejs" "$HM"; \
  [ -f "$BAKDIR/phone_field_assets.ejs" ] && cp -f "$BAKDIR/phone_field_assets.ejs" "$PFA" || rm -f "$PFA"; \
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$PF" "$BAKDIR/phone_field.ejs"; cp -f "$AC" "$BAKDIR/account.js"; cp -f "$HM" "$BAKDIR/hub_model.ejs"
[ -f "$PFA" ] && cp -f "$PFA" "$BAKDIR/phone_field_assets.ejs" || true

echo "==> deploy shared assets + refactored phone_field"
cp -f "$DEPLOY/views/partials/phone_field_assets.ejs" "$PFA"
cp -f "$DEPLOY/views/partials/phone_field.ejs" "$PF"

echo "==> account.js: add GET /api/countries"
export AC
node <<'NODE'
const fs=require('fs'); const F=process.env.AC;
let s=fs.readFileSync(F,'utf8');
if(s.indexOf("/api/countries")>=0){ console.log('   already present'); process.exit(0); }
const anchor="router.get('/login', async (req, res) => {";
const n=s.split(anchor).length-1;
if(n!==1) throw new Error('login-route anchor not unique/found ('+n+')');
const ins="router.get('/api/countries', function(req,res){ try{ res.set('Cache-Control','public, max-age=86400'); res.json(phone.countries()); }catch(e){ res.json([]); } });\n  ";
s=s.split(anchor).join(ins+anchor);
fs.writeFileSync(F,s); console.log('   /api/countries added');
NODE

echo "==> hub_model.ejs: signup picker patches"
export HM
node <<'NODE'
const fs=require('fs'); const F=process.env.HM;
let s=fs.readFileSync(F,'utf8');
function rep(re, neu, label){
  const g=new RegExp(re.source, re.flags.indexOf('g')<0?re.flags+'g':re.flags);
  const n=(s.match(g)||[]).length;
  if(n!==1) throw new Error(label+': expected 1 match, got '+n);
  s=s.replace(re, function(){ return neu; });
  console.log('   - '+label+': ok');
}
// a) shared assets include (idempotent)
if(s.indexOf('phone_field_assets')>=0){ console.log('   - assets include: already present'); }
else { s="<%- include('phone_field_assets') %>\n"+s; console.log('   - assets include: prepended'); }
// b) signup WhatsApp field -> premium picker (keeps #suWa as the number input)
rep(/\+'<div class="cthm-f"><label>WhatsApp number<\/label><input type="text" id="suWa"[^>]*><\/div>'/,
    "+'<div class=\"cthm-f\"><label>WhatsApp number</label>'+window.__pfMarkup({id:'hubsu',name:'suWaNum',numId:'suWa',sel:((window.__GEO&&window.__GEO.country)||'PK'),required:true})+'</div>'",
    'signup field -> picker');
// c) country comes from the picker, not a +/00 guess
rep(/var wc=[^;]*\.test\(wa\)[^;]*;/,
    "var wc=((document.getElementById('pfcc_hubsu')||{}).value)||'PK';",
    'signup wc from picker');
// d) wire the picker after the form is built
rep(/var go=document\.getElementById\('suGo'\);/,
    "if(window.__pfEnsureCC){window.__pfEnsureCC(function(){if(window.__pfInitAll)window.__pfInitAll();});} var go=document.getElementById('suGo');",
    'signup picker init');
fs.writeFileSync(F,s);
NODE

echo "==> compile checks"
node --check "$AC"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");["'"$PFA"'","'"$PF"'","'"$HM"'","'"$GSZ"'/views/account/signup.ejs","'"$GSZ"'/views/account/login.ejs"].forEach(function(f){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});});console.log("   all templates compile OK")'

echo "==> restart + health (10 retries)"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
echo "==> /api/countries check"
curl -sf "http://127.0.0.1:$PORT/api/countries" 2>/dev/null | head -c 80; echo
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE — open the Galaxy Hub pop-up → Create Account. The WhatsApp field is now the"
echo "premium searchable picker (country name + dial code), same as the /signup page."
echo "Backups: $BAKDIR"
