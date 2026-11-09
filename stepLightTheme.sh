#!/usr/bin/env bash
# GSZ Light theme deploy — adds a 2nd theme (Light) alongside the current Midnight look.
# Zero-risk: all CSS is scoped to html[data-theme="light"]; default stays Midnight.
# Safe to re-run (idempotent). Patcher reads real template lines, asserts, backs up,
# validates with ejs.compile, and rolls back on any failure BEFORE restarting.
set -euo pipefail
echo "== GSZ Light theme deploy =="
mkdir -p /opt/gsz/static/css /opt/gsz/static/js

# ---------- 1) light-theme.css ----------
cat > /opt/gsz/static/css/light-theme.css <<'GSZLIGHTCSS'
/* GSZ Light theme — every rule scoped to html[data-theme="light"].
   With no data-theme (default / Midnight) NONE of this applies: the current look is untouched. */
html[data-theme="light"]{
  --bg0:#ffffff;--paper:#f7f8fa;--surface:#ffffff;--surface-2:#eef1f6;--wash:#f3f5f9;
  --ink:#15171c;--ink-soft:#3d4350;--muted:#697086;
  --line:rgba(17,20,30,.10);--line-2:rgba(17,20,30,.17);
  --v:#6d3df5;--b:#2563eb;--c:#0284c7;
  --brand:linear-gradient(100deg,#6d3df5,#2563eb 55%,#0ea5e9);
  --glow:0 0 0 1px rgba(17,20,30,.05),0 20px 60px -24px rgba(37,99,235,.26);
  --shadow:0 1px 3px rgba(17,20,30,.06),0 12px 28px -18px rgba(17,20,30,.22);
  --shadow-lg:0 6px 20px rgba(17,20,30,.08),0 34px 70px -30px rgba(17,20,30,.26);
  --ok:#107a4b;--warn:#8a5a00;--bad:#c4322b;
  color-scheme:light;
}
html[data-theme="light"] body{background:var(--paper)}
html[data-theme="light"] .gsz-theme-toggle{color:var(--ink)}

/* ---- self-contained component token remaps ---- */
html[data-theme="light"] .gbuy{--gb-ink:var(--ink);--gb-mut:var(--muted);--gb-p:var(--surface);--gb-p2:var(--surface-2);--gb-ln:var(--line);--gb-grad:var(--brand)}
html[data-theme="light"] .gna,html[data-theme="light"] .gna-ticker,html[data-theme="light"] .gna-scrim,html[data-theme="light"] .gna-sheet{--gna-ink:var(--ink);--gna-mut:var(--muted);--gna-cyan:var(--b);--gna-ln:var(--line);--gna-grad:var(--brand)}
html[data-theme="light"] .cth{--p:var(--surface);--p2:var(--surface-2);--ph:var(--surface-2);--ln:var(--line);--ln2:var(--line-2);--ink:var(--ink);--ink2:var(--muted);--b:#2563eb;--b2:#0284c7;--grad:var(--brand);--pur:var(--v);--pink:#d6457f}

/* ---- top & bottom nav + Store drawer ---- */
html[data-theme="light"] .gna,html[data-theme="light"] .gna-sheet,html[data-theme="light"] .gna-ticker{background:var(--surface)}
html[data-theme="light"] .gna-scrim{background:rgba(17,20,30,.45)}
html[data-theme="light"] .gbuy{background:var(--surface)}
html[data-theme="light"] .gna-i.on,html[data-theme="light"] .gna-i.on span,html[data-theme="light"] .gna-i.on svg{color:var(--b);stroke:var(--b)}
html[data-theme="light"] .gna-cat,html[data-theme="light"] .gna-cat-dyn{background:var(--surface) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .gna-cat:hover,html[data-theme="light"] .gna-cat-dyn:hover{background:var(--surface-2) !important}
html[data-theme="light"] .gna-cat b,html[data-theme="light"] .gna-cat span{color:var(--ink)}
html[data-theme="light"] .gna-cat small,html[data-theme="light"] .gna-cat .sub{color:var(--muted)}

/* ---- app.css hardcoded light fixes ---- */
html[data-theme="light"] .code-chip{background:var(--surface-2);color:var(--ink)}
html[data-theme="light"] .section.dark{background:var(--wash)}
html[data-theme="light"] .section.dark .sec-head h2,html[data-theme="light"] .section.dark .pcard .pname,html[data-theme="light"] .section.dark .pcard .pprice{color:var(--ink)}
html[data-theme="light"] .section.dark .pcard{background:var(--surface);border-color:var(--line)}
html[data-theme="light"] .section.dark .eyebrow{color:var(--muted)}
html[data-theme="light"] .section.dark .pcard .pdesc{color:var(--ink-soft)}
html[data-theme="light"] .ft-col h4,html[data-theme="light"] .ft-brand .wordmark,html[data-theme="light"] .ft-col a:hover{color:var(--ink)}
html[data-theme="light"] .foot-bottom,html[data-theme="light"] .ft-bottom{border-top-color:var(--line)}
html[data-theme="light"] .pay{background:var(--surface-2);color:var(--ink-soft)}
html[data-theme="light"] .social a{background:var(--surface-2)}
html[data-theme="light"] .gszcart-go,html[data-theme="light"] .btn-primary,html[data-theme="light"] .btn-p{color:#fff;-webkit-text-fill-color:#fff}
html[data-theme="light"] .eyebrow{color:var(--muted)}
html[data-theme="light"] .pdesc,html[data-theme="light"] .pcard .pdesc,html[data-theme="light"] .pdesc *{color:var(--ink-soft)}

/* ---- product page ---- */
html[data-theme="light"] .ppill,html[data-theme="light"] .ppill-label,html[data-theme="light"] .ppill-now{color:var(--ink)}
html[data-theme="light"] .ppill-sub,html[data-theme="light"] .ppill-mut,html[data-theme="light"] .ppill-bell{color:var(--muted)}
html[data-theme="light"] .ppill-stock.in{color:var(--ok)}
html[data-theme="light"] .ppill-stock.out{color:var(--bad)}
html[data-theme="light"] .ppill-save{color:#107a4b;background:rgba(16,122,75,.12);border-color:rgba(16,122,75,.3)}
html[data-theme="light"] .pdp-toprev{color:#b45309 !important}
html[data-theme="light"] .pdp-media .pf{color:#fff}
html[data-theme="light"] .geo-note,html[data-theme="light"] .geo-note span{color:var(--warn)}
html[data-theme="light"] .warr-note,html[data-theme="light"] .warr-note span{color:var(--ok)}
html[data-theme="light"] .rvp-ttl{color:var(--ink)}

/* ---- Galaxy Hub modal (.cthm) + account + support + nested views ---- */
html[data-theme="light"] .cthm-card,html[data-theme="light"] .cthm-x,html[data-theme="light"] .cthm-tab,html[data-theme="light"] .cbtn,html[data-theme="light"] .cbtn-g,html[data-theme="light"] .cthm-auth{background:var(--surface) !important;border-color:var(--line) !important}
html[data-theme="light"] .cthm-tab.on{background:var(--b) !important;border-color:var(--b) !important;color:#fff !important}
html[data-theme="light"] .cthm-head,html[data-theme="light"] .cthm-head h3,html[data-theme="light"] .cthm-card,html[data-theme="light"] .cthm-body,html[data-theme="light"] .cthm-row,html[data-theme="light"] .cthm-acts,html[data-theme="light"] .cthm-foot,html[data-theme="light"] .cthm-fwrap,html[data-theme="light"] .cthm-frow,html[data-theme="light"] .cbtn-g,html[data-theme="light"] .cthm .onm{color:var(--ink)}
html[data-theme="light"] .cthm-tab{color:var(--muted)}
html[data-theme="light"] .cthm-sub,html[data-theme="light"] .cthm-head p,html[data-theme="light"] .cthm-foot small{color:var(--muted)}
html[data-theme="light"] .cthm-scrim{background:rgba(17,20,30,.5)}
html[data-theme="light"] .cthm-auth.out,html[data-theme="light"] .cthm-auth.out *{color:var(--bad) !important;stroke:var(--bad)}
html[data-theme="light"] .cthm-auth.out{border-color:rgba(196,50,43,.4)}
html[data-theme="light"] .acc-fld{background:var(--surface-2) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .acc-lbl{color:var(--muted)}
html[data-theme="light"] .acc-val{color:var(--ink)}
html[data-theme="light"] .acc-input{background:var(--surface) !important;color:var(--ink) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .acc-editbox{color:var(--ink)}
html[data-theme="light"] .cthm input,html[data-theme="light"] .cthm textarea,html[data-theme="light"] .cthm select{background:var(--surface) !important;color:var(--ink) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .cthm input::placeholder,html[data-theme="light"] .cthm textarea::placeholder{color:var(--muted)}
html[data-theme="light"] .cthm-chip{background:var(--surface-2) !important;color:var(--ink) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .sb-b,html[data-theme="light"] .sb-bot{background:var(--surface) !important;color:var(--ink) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .sb-wa{color:var(--muted);border-color:var(--line)}
html[data-theme="light"] .sb-wa b{color:#15803d}
html[data-theme="light"] .cthm-ord,html[data-theme="light"] .cthm-choice{background:var(--surface-2) !important;border:1px solid var(--line) !important;color:var(--ink)}
html[data-theme="light"] .cthm-ord *,html[data-theme="light"] .cthm-choice *{border-color:var(--line)}
html[data-theme="light"] .cthm small,html[data-theme="light"] .osub,html[data-theme="light"] .cthm .sub,html[data-theme="light"] .cthm [class*=sub],html[data-theme="light"] .cthm [class*=mut]{color:var(--muted)}
html[data-theme="light"] .cthm-pill.ok{color:var(--ok) !important;background:rgba(16,122,75,.10) !important;border-color:rgba(16,122,75,.3) !important}
html[data-theme="light"] .cthm-pill.warn,html[data-theme="light"] .cthm-pill.wait{color:var(--warn) !important;background:rgba(138,90,0,.10) !important;border-color:rgba(138,90,0,.3) !important}
html[data-theme="light"] .cthm-pill.bad{color:var(--bad) !important}
html[data-theme="light"] .cbtn-p,html[data-theme="light"] .cbtn-g:not(.acc-ic){background:var(--brand) !important;border-color:transparent !important;color:#fff !important;-webkit-text-fill-color:#fff !important}
html[data-theme="light"] .cbtn-p *,html[data-theme="light"] .cbtn-g:not(.acc-ic) *{color:#fff !important;stroke:#fff}
html[data-theme="light"] .oc{background:var(--surface) !important;border:1px solid var(--line) !important;color:var(--ink)}
html[data-theme="light"] .oc-row{background:var(--surface-2) !important;border:1px solid var(--line) !important;color:var(--ink)}
html[data-theme="light"] .oc *{border-color:var(--line)}
html[data-theme="light"] .oc [class*=lbl],html[data-theme="light"] .oc [class*=k],html[data-theme="light"] .oc small,html[data-theme="light"] .oc [class*=sub],html[data-theme="light"] .oc [class*=mut]{color:var(--muted)}
html[data-theme="light"] .oc [class*=val],html[data-theme="light"] .oc b,html[data-theme="light"] .oc strong,html[data-theme="light"] .oc h1,html[data-theme="light"] .oc h2,html[data-theme="light"] .oc h3,html[data-theme="light"] .oc h4{color:var(--ink)}
html[data-theme="light"] .oc input,html[data-theme="light"] .oc textarea{background:var(--surface) !important;color:var(--ink) !important;border:1px solid var(--line) !important}
html[data-theme="light"] .cthm-back{color:var(--b)}
html[data-theme="light"] .oc-pill{color:var(--ok)}
html[data-theme="light"] .oc-pill.warn,html[data-theme="light"] .oc-pill.wait{color:var(--warn)}
html[data-theme="light"] .oc-pill.bad,html[data-theme="light"] .oc-pill.exp,html[data-theme="light"] .oc-pill.expired{color:var(--bad)}
GSZLIGHTCSS
echo "  wrote static/css/light-theme.css"

# ---------- 2) themes.js (engine + header Light/Dark toggle) ----------
cat > /opt/gsz/static/js/themes.js <<'GSZTHEMESJS'
(function(){
  var KEY='gsz_theme';
  var D=document.documentElement;
  function cur(){ return D.getAttribute('data-theme')==='light' ? 'light' : 'midnight'; }
  function apply(t){
    if(t==='light'){ D.setAttribute('data-theme','light'); } else { D.removeAttribute('data-theme'); }
    try{ localStorage.setItem(KEY,t); }catch(e){}
    paint();
  }
  var SUN='<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4.2"/><path d="M12 2v2.3M12 19.7V22M2 12h2.3M19.7 12H22M4.9 4.9l1.6 1.6M17.5 17.5l1.6 1.6M19.1 4.9l-1.6 1.6M6.5 17.5l-1.6 1.6"/></svg>';
  var MOON='<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A8.5 8.5 0 1 1 11.2 3 6.6 6.6 0 0 0 21 12.8z"/></svg>';
  function paint(){
    var b=document.getElementById('gsz-theme-toggle'); if(!b) return;
    var light=cur()==='light';
    b.innerHTML = light ? MOON : SUN;
    var lbl = light ? 'Switch to dark' : 'Switch to light';
    b.setAttribute('aria-label',lbl); b.title=lbl;
  }
  function mount(){
    if(document.getElementById('gsz-theme-toggle')) return;
    var b=document.createElement('button');
    b.id='gsz-theme-toggle'; b.type='button'; b.className='icon-btn gsz-theme-toggle';
    b.addEventListener('click',function(){ apply(cur()==='light' ? 'midnight' : 'light'); });
    var host=document.querySelector('.hd-tools');
    if(host){
      var burger=host.querySelector('.burger');
      if(burger){ host.insertBefore(b,burger); } else { host.insertBefore(b,host.firstChild); }
    } else {
      b.style.position='fixed'; b.style.right='14px'; b.style.bottom='calc(env(safe-area-inset-bottom,0px) + 90px)';
      b.style.zIndex='9000'; b.style.width='44px'; b.style.height='44px'; b.style.borderRadius='50%';
      b.style.display='grid'; b.style.placeItems='center'; b.style.border='1px solid rgba(128,128,128,.3)';
      b.style.background='var(--surface,#fff)'; b.style.color='var(--ink,#111)'; b.style.boxShadow='0 10px 26px -12px rgba(0,0,0,.5)';
      document.body.appendChild(b);
    }
    paint();
  }
  if(document.readyState==='loading'){ document.addEventListener('DOMContentLoaded',mount); } else { mount(); }
})();
GSZTHEMESJS
echo "  wrote static/js/themes.js"

# ---------- 3) template patcher (reads real lines, asserts, backs up, validates, rolls back) ----------
cat > /tmp/gsz-theme-patch.js <<'GSZPATCH'
const fs=require('fs');
const cp=require('child_process');
const ejs=require('/opt/gsz/node_modules/ejs');
const ROOT='/opt/gsz';
const BAKDIR=ROOT+'/.gsz-theme-bak';
try{ fs.mkdirSync(BAKDIR,{recursive:true}); }catch(e){}
const ts=Date.now();
const backups=[];
function fail(msg){
  console.error('PATCH FAILED: '+msg);
  for(const b of backups){ try{ fs.copyFileSync(b.bak,b.orig); console.error('  reverted '+b.orig); }catch(e){} }
  process.exit(1);
}
function backup(f){ const bak=BAKDIR+'/'+f.split('/').pop()+'.'+ts+'.bak'; fs.copyFileSync(f,bak); backups.push({orig:f,bak}); }
function validate(f){ try{ ejs.compile(fs.readFileSync(f,'utf8'),{includer:function(){return {template:''};}}); }catch(e){ fail('ejs compile '+f+': '+e.message); } }
function grepFiles(needle){
  const out=cp.execSync('grep -rl '+JSON.stringify(needle)+' '+ROOT+'/views || true').toString().trim();
  return (out ? out.split('\n') : []).filter(function(f){ return /\.ejs$/.test(f) && f.indexOf('.bak')<0; });
}
const PREPAINT='<script>(function(){try{var t=localStorage.getItem("gsz_theme");if(!t)t=(window.__GSZ_DEFAULT_THEME__||"midnight");if(t==="light")document.documentElement.setAttribute("data-theme","light");}catch(e){}})();</script>';
const LIGHTLINK='<link rel="stylesheet" href="/static/css/light-theme.css?v='+ts+'">';
const THEMESJS='<script src="/static/js/themes.js?v='+ts+'" defer></script>';

// --- HEAD: pre-paint + light-theme.css right around the app.css <link> ---
let headFiles=grepFiles('static/css/app.css');
if(!headFiles.length) fail('no template contains the app.css <link>');
let headDone=0, headSkip=0;
for(const f of headFiles){
  let s=fs.readFileSync(f,'utf8');
  if(s.indexOf('light-theme.css')>=0){ headSkip++; continue; }
  const lines=s.split('\n');
  const matches=lines.map((l,i)=>({l,i})).filter(o=>/app\.css/.test(o.l)&&/<link/i.test(o.l));
  if(matches.length!==1) fail('expected exactly 1 app.css <link> line in '+f+', found '+matches.length);
  const idx=matches[0].i;
  backup(f);
  const out=[];
  lines.forEach((l,i)=>{ if(i===idx){ out.push('  '+PREPAINT); out.push(l); out.push('  '+LIGHTLINK); } else { out.push(l); } });
  fs.writeFileSync(f,out.join('\n'));
  validate(f);
  headDone++;
}

// --- FOOT (storefront): themes.js right after the app.js <script> ---
let footFiles=grepFiles('static/js/app.js');
if(!footFiles.length) fail('no template contains the app.js <script>');
let footDone=0, footSkip=0;
for(const f of footFiles){
  let s=fs.readFileSync(f,'utf8');
  if(s.indexOf('themes.js')>=0){ footSkip++; continue; }
  const lines=s.split('\n');
  const matches=lines.map((l,i)=>({l,i})).filter(o=>/static\/js\/app\.js/.test(o.l)&&/<script/i.test(o.l));
  if(matches.length!==1) fail('expected exactly 1 app.js <script> line in '+f+', found '+matches.length);
  const idx=matches[0].i;
  backup(f);
  const out=[];
  lines.forEach((l,i)=>{ out.push(l); if(i===idx){ out.push('  '+THEMESJS); } });
  fs.writeFileSync(f,out.join('\n'));
  validate(f);
  footDone++;
}
console.log('  head: '+headDone+' patched, '+headSkip+' already done; foot: '+footDone+' patched, '+footSkip+' already done');
GSZPATCH

node /tmp/gsz-theme-patch.js

# ---------- 4) restart + verify the real page ----------
pm2 restart gsz --update-env >/dev/null
sleep 2
if curl -fsS -H 'Host: galaxyzayron.store' http://127.0.0.1:3900/ | grep -q 'light-theme.css'; then
  echo "OK: light-theme.css is present on the live home page"
else
  echo "WARN: light-theme.css NOT found on rendered home — tell Claude"
fi
echo "== done =="
