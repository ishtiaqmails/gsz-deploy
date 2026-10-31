#!/usr/bin/env bash
# stepHubSignin.sh — upgrade the Galaxy Hub SIGN IN form to match /login + Create Account:
# an Email / Phone toggle, with the premium picker on the Phone side. Posts email OR phone
# (+ wa_country) to the same /login endpoint. Reuses __pfMarkup (one shared picker).
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.signinbak.$TS"; mkdir -p "$BAKDIR"
HM="$GSZ/views/partials/hub_model.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/hub_model.ejs" ] && cp -f "$BAKDIR/hub_model.ejs" "$HM"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$HM" "$BAKDIR/hub_model.ejs"

echo "==> patch hub sign-in"
export HM
node <<'NODE'
const fs=require('fs'); const F=process.env.HM;
let s=fs.readFileSync(F,'utf8');
if(s.indexOf("id:'hubsi'")>=0){ console.log('   already upgraded'); process.exit(0); }
function rep(re, neu, label, want){
  const g=new RegExp(re.source, re.flags.indexOf('g')<0?re.flags+'g':re.flags);
  const n=(s.match(g)||[]).length;
  if(want===0){ if(n<1) throw new Error(label+': expected >=1, got 0'); }
  else if(n!==(want||1)) throw new Error(label+': expected '+(want||1)+', got '+n);
  s=s.replace(g, function(){ return neu; });
  console.log('   - '+label+': ok ('+n+')');
}
// CSS for the toggle (hub blue accent)
rep(/\.cthm-card\.cthm-authmode \.pf-cc,\.cthm-card\.cthm-authmode \.pf-numin\{padding-top:9px;padding-bottom:9px\}/,
    ".cthm-card.cthm-authmode .pf-cc,.cthm-card.cthm-authmode .pf-numin{padding-top:9px;padding-bottom:9px}\n"
   +"   .hbtab{display:flex;gap:6px;padding:5px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.08);border-radius:12px;margin:0 0 13px}\n"
   +"   .hbtab-b{flex:1;padding:9px 0;border:0;border-radius:9px;background:transparent;color:#9aa6c0;font:inherit;font-weight:700;font-size:13px;cursor:pointer}\n"
   +"   .hbtab-b.on{background:linear-gradient(135deg,#2f7bff,#29d3ff);color:#fff}\n"
   +"   .hbpane{display:none}.hbpane.on{display:block}",
    'hbtab css');
// 1) field -> Email/Phone tabs + panes
rep(/\+'<div class="cthm-f"><label>Email or WhatsApp<\/label><input type="text" id="auId"[^>]*><\/div>'/,
    "+'<div class=\"hbtab\"><button type=\"button\" class=\"hbtab-b on\" data-ht=\"email\">Email</button><button type=\"button\" class=\"hbtab-b\" data-ht=\"phone\">Phone</button></div>'\n      +'<div class=\"hbpane on\" data-hp=\"email\"><div class=\"cthm-f\"><label>Email address</label><input type=\"email\" id=\"auEmail\" placeholder=\"you@email.com\"></div></div>'\n      +'<div class=\"hbpane\" data-hp=\"phone\"><div class=\"cthm-f\"><label>WhatsApp number</label>'+window.__pfMarkup({id:'hubsi',name:'auWaNum',numId:'auWa',sel:((window.__GEO&&window.__GEO.country)||'PK')})+'</div></div>'",
    'signin field->tabs');
// 2) read identifier from the active tab, capture wa_country for phone
rep(/var id=\(document\.getElementById\('auId'\)\.value\|\|''\)\.trim\(\), /,
    "var _ph=!!document.querySelector('.hbpane[data-hp=\"phone\"].on'); var _wc=_ph?(((document.getElementById('pfcc_hubsi')||{}).value)||'PK'):''; var id=(_ph?((document.getElementById('auWa')||{}).value||''):((document.getElementById('auEmail')||{}).value||'')).trim(); var ",
    'signin id-read');
// 3) include wa_country in the POST when phone
rep(/new URLSearchParams\(\{email:id,password:pw\}\)/,
    "new URLSearchParams(_wc?{email:id,password:pw,wa_country:_wc}:{email:id,password:pw})",
    'signin fetch body');
// 4) don't let the picker search submit on Enter (both signin + forgot)
rep(/body\.querySelectorAll\('input'\)\.forEach\(function\(i\)\{ i\.addEventListener\('keydown',function\(e\)\{ if\(e\.key==='Enter'\) submit\(\); \}\); \}\);/,
    "body.querySelectorAll('input:not(.pf-search)').forEach(function(i){ i.addEventListener('keydown',function(e){ if(e.key==='Enter') submit(); }); });",
    'enter-submit exclude search', 0);
// 5) wire the tabs + init the picker
rep(/var go=document\.getElementById\('auGo'\);/,
    "(function(){var tb=document.querySelectorAll('#cthmBody .hbtab-b');var pn=document.querySelectorAll('#cthmBody .hbpane');tb.forEach(function(b){b.addEventListener('click',function(){var w=b.getAttribute('data-ht');tb.forEach(function(x){x.classList.toggle('on',x===b);});pn.forEach(function(p){p.classList.toggle('on',p.getAttribute('data-hp')===w);});var f=(w==='phone')?document.getElementById('auWa'):document.getElementById('auEmail');if(f){try{f.focus();}catch(e){}}});});if(window.__pfEnsureCC){window.__pfEnsureCC(function(){if(window.__pfInitAll)window.__pfInitAll();});}})(); var go=document.getElementById('auGo');",
    'signin tab wiring + picker init');
fs.writeFileSync(F,s);
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$HM"'","utf8"),{filename:"'"$HM"'"});console.log("   compiles OK")'
echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — Hub Sign In now has the Email/Phone toggle + picker, matching everywhere else."
echo "Backups: $BAKDIR"
