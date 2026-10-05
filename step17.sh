#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 17: world-currency popup + IPTV resellers
#  RUN: cd /opt/gsz-deploy && git pull && bash step17.sh
#   - Replaces the 4-region switcher with a G2A-style CURRENCY popup:
#     searchable list of 40+ world currencies, live exchange rates
#     (fetched in the customer's browser, cached 24h, static fallback).
#     Prices across the site repaint instantly in the chosen currency.
#   - Resellers page rewritten to IPTV reseller PANELS only (own credits,
#     own prices, create/renew lines, free trials, WhatsApp setup).
#  Files: public/js/app.js, public/css/app.css,
#         views/partials/store_top.ejs, views/partials/store_bottom.ejs,
#         views/resellers.ejs
#  Asset version -> v=17. Auto-rollback on health-check failure.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found"; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"
echo "== Galaxy Subz x Zayron — Step 17 (currency popup + IPTV resellers) · port $PORT =="
ts=$(date +%s)
cp -a "$APP/public/js/app.js"                "$APP/public/js/app.js.bak-step17.$ts"
cp -a "$APP/public/css/app.css"              "$APP/public/css/app.css.bak-step17.$ts"
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step17.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step17.$ts"
cp -a "$APP/views/resellers.ejs"             "$APP/views/resellers.ejs.bak-step17.$ts"
restore(){
  echo ">> rolling back Step 17"
  cp -a "$APP/public/js/app.js.bak-step17.$ts"                "$APP/public/js/app.js"
  cp -a "$APP/public/css/app.css.bak-step17.$ts"              "$APP/public/css/app.css"
  cp -a "$APP/views/partials/store_top.ejs.bak-step17.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step17.$ts" "$APP/views/partials/store_bottom.ejs"
  cp -a "$APP/views/resellers.ejs.bak-step17.$ts"             "$APP/views/resellers.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}
cat > "$APP/public/js/app.js" <<'GSZ_JS17'
/* ===== Galaxy Subz × Zayron — storefront (v2) =====
   Server renders the markup; this handles interaction only:
   region prices, live search, hero carousel, drawer, marquee, toss. */
(function(){
'use strict';
try{document.documentElement.classList.add('gsz-js');}catch(e){}
var D = (window.__DATA)||{cats:[],products:[],settings:{},wa:''};
var CATS = D.cats||[], PRODUCTS = D.products||[];
var reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;
var $ = function(s,r){return (r||document).querySelector(s);};
var $$ = function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s));};

/* ---------- currency + prices (G2A-style world currency) ----------
   Prices are stored in PKR (data-pkr). rate = units of the currency per 1 PKR.
   Static rates are an approximate fallback; live rates refresh them on load. */
var CURRENCIES=[
  {code:'PKR',name:'Pakistani Rupee',sym:'Rs',cc:'pk',rate:1},
  {code:'USD',name:'US Dollar',sym:'$',cc:'us',rate:0.00360},
  {code:'EUR',name:'Euro',sym:'€',cc:'eu',rate:0.00332},
  {code:'GBP',name:'British Pound',sym:'£',cc:'gb',rate:0.00284},
  {code:'AED',name:'UAE Dirham',sym:'AED',cc:'ae',rate:0.01322},
  {code:'SAR',name:'Saudi Riyal',sym:'SAR',cc:'sa',rate:0.01350},
  {code:'INR',name:'Indian Rupee',sym:'₹',cc:'in',rate:0.3005},
  {code:'CAD',name:'Canadian Dollar',sym:'C$',cc:'ca',rate:0.00492},
  {code:'AUD',name:'Australian Dollar',sym:'A$',cc:'au',rate:0.00549},
  {code:'CNY',name:'Chinese Yuan',sym:'¥',cc:'cn',rate:0.0257},
  {code:'JPY',name:'Japanese Yen',sym:'¥',cc:'jp',rate:0.539},
  {code:'TRY',name:'Turkish Lira',sym:'₺',cc:'tr',rate:0.1230},
  {code:'RUB',name:'Russian Ruble',sym:'₽',cc:'ru',rate:0.3360},
  {code:'BRL',name:'Brazilian Real',sym:'R$',cc:'br',rate:0.0196},
  {code:'ZAR',name:'South African Rand',sym:'R',cc:'za',rate:0.0637},
  {code:'NGN',name:'Nigerian Naira',sym:'₦',cc:'ng',rate:5.60},
  {code:'EGP',name:'Egyptian Pound',sym:'E£',cc:'eg',rate:0.1725},
  {code:'BDT',name:'Bangladeshi Taka',sym:'৳',cc:'bd',rate:0.4300},
  {code:'IDR',name:'Indonesian Rupiah',sym:'Rp',cc:'id',rate:57.0},
  {code:'MYR',name:'Malaysian Ringgit',sym:'RM',cc:'my',rate:0.0160},
  {code:'SGD',name:'Singapore Dollar',sym:'S$',cc:'sg',rate:0.00462},
  {code:'HKD',name:'Hong Kong Dollar',sym:'HK$',cc:'hk',rate:0.0280},
  {code:'NZD',name:'New Zealand Dollar',sym:'NZ$',cc:'nz',rate:0.00600},
  {code:'CHF',name:'Swiss Franc',sym:'CHF',cc:'ch',rate:0.00305},
  {code:'SEK',name:'Swedish Krona',sym:'kr',cc:'se',rate:0.0378},
  {code:'NOK',name:'Norwegian Krone',sym:'kr',cc:'no',rate:0.0385},
  {code:'DKK',name:'Danish Krone',sym:'kr',cc:'dk',rate:0.0247},
  {code:'PLN',name:'Polish Zloty',sym:'zł',cc:'pl',rate:0.0142},
  {code:'QAR',name:'Qatari Riyal',sym:'QAR',cc:'qa',rate:0.01310},
  {code:'KWD',name:'Kuwaiti Dinar',sym:'KWD',cc:'kw',rate:0.00110},
  {code:'BHD',name:'Bahraini Dinar',sym:'BHD',cc:'bh',rate:0.00135},
  {code:'OMR',name:'Omani Rial',sym:'OMR',cc:'om',rate:0.00138},
  {code:'THB',name:'Thai Baht',sym:'฿',cc:'th',rate:0.1180},
  {code:'PHP',name:'Philippine Peso',sym:'₱',cc:'ph',rate:0.2020},
  {code:'VND',name:'Vietnamese Dong',sym:'₫',cc:'vn',rate:91.0},
  {code:'LKR',name:'Sri Lankan Rupee',sym:'Rs',cc:'lk',rate:1.080},
  {code:'NPR',name:'Nepalese Rupee',sym:'Rs',cc:'np',rate:0.4800},
  {code:'MXN',name:'Mexican Peso',sym:'Mex$',cc:'mx',rate:0.0660},
  {code:'KES',name:'Kenyan Shilling',sym:'KSh',cc:'ke',rate:0.4650},
  {code:'MAD',name:'Moroccan Dirham',sym:'MAD',cc:'ma',rate:0.0355},
  {code:'UAH',name:'Ukrainian Hryvnia',sym:'₴',cc:'ua',rate:0.1480}
];
var CUR=CURRENCIES[0];
try{var sv=localStorage.getItem('gsz_currency');if(sv){var f0=CURRENCIES.filter(function(c){return c.code===sv;})[0];if(f0)CUR=f0;}}catch(e){}
function flag(cc){return 'https://flagcdn.com/24x18/'+cc+'.png';}
function money(pkr){pkr=Number(pkr)||0;
  if(CUR.code==='PKR')return 'Rs '+Math.round(pkr).toLocaleString('en-US');
  var v=pkr*CUR.rate;
  var num=v<10?v.toFixed(2):Math.round(v).toLocaleString('en-US');
  return (/[A-Za-z]$/.test(CUR.sym)?(CUR.sym+' '):CUR.sym)+num;}
function paintPrices(root){$$('[data-pkr]',root).forEach(function(el){el.textContent=money(el.dataset.pkr);});}
function setCurrency(code){
  var f=CURRENCIES.filter(function(c){return c.code===code;})[0]; if(!f)return;
  CUR=f;
  var lab=$('#curLabel'); if(lab)lab.textContent=f.code;
  var fl=$('#curFlag'); if(fl)fl.src=flag(f.cc);
  paintPrices();
  $$('#curList button').forEach(function(b){b.classList.toggle('on',b.dataset.code===code);});
  try{localStorage.setItem('gsz_currency',code);}catch(e){}
}
function buildCurList(filter){
  var el=$('#curList'); if(!el)return;
  filter=(filter||'').trim().toLowerCase();
  var list=CURRENCIES.filter(function(c){return !filter || c.code.toLowerCase().indexOf(filter)>-1 || c.name.toLowerCase().indexOf(filter)>-1;});
  if(!list.length){el.innerHTML='<div class="sempty">No currency matches.</div>';return;}
  el.innerHTML=list.map(function(c){
    return '<button type="button" data-code="'+c.code+'" class="cur-item'+(c.code===CUR.code?' on':'')+'">'+
      '<img class="flag" src="'+flag(c.cc)+'" alt=""><span class="cc">'+c.code+'</span><span class="cn">'+c.name+'</span><span class="cs">'+c.sym+'</span></button>';
  }).join('');
}
function openCur(){var m=$('#curModal'); if(!m)return; m.classList.add('on'); document.body.style.overflow='hidden';
  var s=$('#curSearch'); if(s){s.value='';buildCurList('');setTimeout(function(){try{s.focus();}catch(e){}},60);}}
function closeCur(){var m=$('#curModal'); if(m)m.classList.remove('on'); document.body.style.overflow='';}
/* live exchange rates (customer's browser; cached 24h; silent fallback to static) */
function applyRates(rates){CURRENCIES.forEach(function(c){if(c.code!=='PKR'&&rates[c.code])c.rate=rates[c.code];});}
function loadRates(){
  try{var cached=JSON.parse(localStorage.getItem('gsz_rates')||'null');
    if(cached&&cached.t&&(Date.now()-cached.t<86400000)&&cached.rates){applyRates(cached.rates);paintPrices();return;}}catch(e){}
  if(!('fetch' in window))return;
  fetch('https://open.er-api.com/v6/latest/PKR').then(function(r){return r.json();}).then(function(d){
    if(d&&d.rates){applyRates(d.rates);try{localStorage.setItem('gsz_rates',JSON.stringify({t:Date.now(),rates:d.rates}));}catch(e){}paintPrices();}
  }).catch(function(){});
}

/* ---------- marquee ---------- */
function buildMarquee(){
  var el=$('#marqueeList'); if(!el)return;
  var items=['Instant automated delivery','Pay in PKR, USD or crypto','Verified before we deliver','Real WhatsApp support','Free IPTV trial available','Thousands of live channels & VOD','Works on every device','Trusted since 2021'];
  var shield='<svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/></svg>';
  var row=items.map(function(t){return '<li>'+shield+t+'</li>';}).join('');
  // duplicated once; CSS animates translateX(-50%) for a seamless loop
  el.innerHTML=row+row;
}

/* ---------- drawer ---------- */
function buildDrawerCats(){
  var el=$('#drawerCats'); if(!el)return;
  el.innerHTML=CATS.map(function(c){
    return '<a class="dcat" href="/category/'+c.slug+'" style="--g1:'+(c.g1||'#2a6cff')+';--g2:'+(c.g2||'#19c6ee')+'">'+
      '<span class="cg"><svg class="ic" viewBox="0 0 24 24">'+(c.icon||'')+'</svg></span>'+
      '<span><b>'+c.name+'</b><span class="n">'+c.n+' product'+(c.n===1?'':'s')+'</span></span></a>';}).join('');
}
function openDrawer(){$('#drawer').classList.add('on');$('#scrim').classList.add('on');}
function closeDrawer(){$('#drawer').classList.remove('on');$('#scrim').classList.remove('on');}

/* ---------- live search (inline, no popup) ---------- */
function searchThumb(p){
  if(p.image)return '<img class="th" src="/static/img/'+p.image+'" alt="">';
  return '<span class="th" style="display:grid;place-items:center;color:#fff;font-weight:700;background:linear-gradient(135deg,#2a6cff,#19c6ee)">'+(p.name||'?').charAt(0).toUpperCase()+'</span>';
}
function runSearch(q){
  var box=$('#searchRes'); if(!box)return;
  q=(q||'').trim().toLowerCase();
  if(!q){box.classList.remove('on');box.innerHTML='';return;}
  var hits=PRODUCTS.filter(function(p){return (p.name||'').toLowerCase().indexOf(q)>-1 || (p.cat||'').toLowerCase().indexOf(q)>-1;}).slice(0,8);
  if(!hits.length){box.innerHTML='<div class="sempty">No products match “'+q.replace(/</g,'')+'”.</div>';box.classList.add('on');return;}
  box.innerHTML=hits.map(function(p){
    return '<a class="sresult" href="/product/'+p.slug+'">'+searchThumb(p)+
      '<span><span class="nm">'+p.name+'</span><span class="mt">'+(p.catName||p.cat||'')+'</span></span>'+
      (p.from>0?'<span class="pr">'+money(p.from)+'</span>':'')+'</a>';}).join('');
  box.classList.add('on');
}

/* ---------- hero carousel (opacity only, no zoom) ---------- */
function initHero(){
  var stage=$('#heroStage'); if(!stage)return;
  var slides=$$('.hslide',stage); if(slides.length<2){return;}
  var dots=$('#heroDots'), cur=0, timer;
  if(dots)dots.innerHTML=slides.map(function(_,i){return '<button data-i="'+i+'" class="'+(i===0?'on':'')+'" aria-label="Slide '+(i+1)+'"></button>';}).join('');
  function go(i){cur=(i+slides.length)%slides.length;
    slides.forEach(function(s,k){s.classList.toggle('on',k===cur);});
    if(dots)$$('button',dots).forEach(function(b,k){b.classList.toggle('on',k===cur);});}
  function start(){if(reduce)return;clearInterval(timer);timer=setInterval(function(){go(cur+1);},6500);}
  var pv=$('#heroPrev'),nx=$('#heroNext');
  if(pv)pv.onclick=function(){go(cur-1);start();};
  if(nx)nx.onclick=function(){go(cur+1);start();};
  if(dots)dots.addEventListener('click',function(e){var b=e.target.closest('button');if(b){go(+b.dataset.i);start();}});
  stage.addEventListener('mouseenter',function(){clearInterval(timer);});
  stage.addEventListener('mouseleave',start);
  start();
}

/* ---------- toss (social proof) — slow, minutes apart ---------- */
var tossT;
function tossThumb(p){
  if(p.image)return '<span class="tt tt-img"><img src="/static/img/'+p.image+'" alt=""></span>';
  var g1=(p.g1||'#2a6cff'),g2=(p.g2||'#19c6ee');
  return '<span class="tt" style="background:linear-gradient(135deg,'+g1+','+g2+')">'+(p.name||'?').charAt(0).toUpperCase()+'</span>';
}
function showToss(){
  var el=$('#toss'); if(!el||!PRODUCTS.length)return;
  var p=PRODUCTS[Math.floor(Math.random()*PRODUCTS.length)];
  var mins=2+Math.floor(Math.random()*28);
  el.innerHTML=tossThumb(p)+
    '<span class="tb"><b>'+p.name+'</b><span>Someone just ordered · '+mins+' min ago</span></span>'+
    '<button class="tx" aria-label="Dismiss">✕</button>';
  el.href='/product/'+p.slug; el.style.display='flex';
  requestAnimationFrame(function(){el.classList.add('on');});
  clearTimeout(tossT); tossT=setTimeout(function(){el.classList.remove('on');},6500);
}
function startToss(){
  if(reduce)return;
  setTimeout(function loop(){showToss();setTimeout(loop,180000+Math.random()*180000);},45000);
}

/* ---------- toast ---------- */
var toastT;
function toast(m){var t=$('#toast');if(!t)return;t.textContent=m;t.classList.add('on');clearTimeout(toastT);toastT=setTimeout(function(){t.classList.remove('on');},2600);}

/* ---------- motion & depth ---------- */
function initTilt(){
  if(matchMedia('(pointer:coarse)').matches || reduce)return;
  $$('.pcard, .cat-tile, .rev').forEach(function(el){
    el.addEventListener('pointermove',function(e){
      var r=el.getBoundingClientRect();
      var px=(e.clientX-r.left)/r.width-0.5, py=(e.clientY-r.top)/r.height-0.5;
      el.style.transform='perspective(820px) rotateX('+(-py*6).toFixed(2)+'deg) rotateY('+(px*7).toFixed(2)+'deg) translateY(-4px)';
    });
    el.addEventListener('pointerleave',function(){el.style.transform='';});
  });
}
function initReveal(){
  var els=$$('.reveal');
  if(reduce || !('IntersectionObserver' in window)){els.forEach(function(e){e.classList.add('in');});return;}
  var io=new IntersectionObserver(function(ents){ents.forEach(function(en){if(en.isIntersecting){en.target.classList.add('in');io.unobserve(en.target);}});},{threshold:0,rootMargin:'0px 0px -40px 0px'});
  els.forEach(function(e){io.observe(e);});
  // safety: reveal anything already in view on load (covers tall sections / no-fire)
  setTimeout(function(){els.forEach(function(e){var r=e.getBoundingClientRect();if(r.top < (innerHeight||800) && r.bottom>0)e.classList.add('in');});},120);
}
/* hero shows the WHOLE banner now — no zoom/parallax so nothing is cropped */
function initParallax(){ return; }

/* ---------- number count-up ---------- */
function animateCount(el){
  var raw=el.getAttribute('data-count'); var target=parseFloat(raw); if(isNaN(target))return;
  var dec=(raw.indexOf('.')>-1)?(raw.split('.')[1].length):0;
  var suffix=el.getAttribute('data-suffix')||'';
  var prefix=el.getAttribute('data-prefix')||'';
  if(reduce){el.textContent=prefix+Number(target).toLocaleString('en-US')+suffix;return;}
  var start=null, dur=1400;
  function step(ts){
    if(start===null)start=ts;
    var p=Math.min((ts-start)/dur,1);
    var eased=1-Math.pow(1-p,3);
    var val=target*eased;
    var shown=dec?val.toFixed(dec):Math.round(val).toLocaleString('en-US');
    el.textContent=prefix+shown+suffix;
    if(p<1)requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}
function initCount(){
  var els=$$('[data-count]'); if(!els.length)return;
  if(reduce || !('IntersectionObserver' in window)){els.forEach(animateCount);return;}
  var io=new IntersectionObserver(function(ents){ents.forEach(function(en){if(en.isIntersecting){animateCount(en.target);io.unobserve(en.target);}});},{threshold:0.4});
  els.forEach(function(e){io.observe(e);});
  setTimeout(function(){els.forEach(function(e){var r=e.getBoundingClientRect();if(r.top<(innerHeight||800)&&r.bottom>0&&!e.dataset.done){e.dataset.done='1';animateCount(e);}});},200);
}

/* ---------- wire ---------- */
function wire(){
  buildCurList(''); buildMarquee(); buildDrawerCats();
  setCurrency(CUR.code); paintPrices(); loadRates();
  initHero(); startToss();
  initReveal(); initTilt(); initParallax(); initCount();

  var rb=$('#curBtn'); if(rb)rb.onclick=function(e){e.preventDefault();e.stopPropagation();openCur();};
  var dcur=$('#drawerCurrency'); if(dcur)dcur.onclick=function(e){e.preventDefault();closeDrawer();openCur();};
  var cClose=$('#curClose'); if(cClose)cClose.onclick=closeCur;
  var cBack=$('#curBackdrop'); if(cBack)cBack.onclick=closeCur;
  var cs=$('#curSearch'); if(cs)cs.addEventListener('input',function(){buildCurList(cs.value);});
  var cl=$('#curList'); if(cl)cl.addEventListener('click',function(e){var b=e.target.closest('[data-code]');if(b){setCurrency(b.dataset.code);closeCur();}});

  document.addEventListener('click',function(e){
    var sc=e.target.closest('[data-scroll]'); if(sc){e.preventDefault();var t=document.getElementById(sc.dataset.scroll);if(t)window.scrollTo({top:t.getBoundingClientRect().top+scrollY-90,behavior:'smooth'});}
    var tt=e.target.closest('[data-toast]'); if(tt){e.preventDefault();toast(tt.dataset.toast);}
    if(!e.target.closest('.hd-search')){var sr=$('#searchRes');if(sr)sr.classList.remove('on');}
  });

  var si=$('#searchInput');
  if(si){si.addEventListener('input',function(){runSearch(si.value);});
    si.addEventListener('focus',function(){if(si.value)runSearch(si.value);});}

  var bg=$('#burger'); if(bg)bg.onclick=openDrawer;
  var dx=$('#drawerX'); if(dx)dx.onclick=closeDrawer;
  var sc=$('#scrim'); if(sc)sc.onclick=closeDrawer;

  var cc=$('#codeChip'); if(cc)cc.onclick=function(){try{navigator.clipboard.writeText('GALAXY10');toast('Code GALAXY10 copied');}catch(e){toast('Code: GALAXY10');}};

  var toss=$('#toss'); if(toss)toss.addEventListener('click',function(e){if(e.target.closest('.tx')){e.preventDefault();toss.classList.remove('on');}});

  var hd=$('#hd'); addEventListener('scroll',function(){hd.classList.toggle('scrolled',scrollY>8);},{passive:true});
  addEventListener('keydown',function(e){if(e.key==='Escape'){closeDrawer();closeCur();var sr=$('#searchRes');if(sr)sr.classList.remove('on');}});
}
if(document.readyState!=='loading')wire(); else document.addEventListener('DOMContentLoaded',wire);
})();

GSZ_JS17

cat > "$APP/public/css/app.css" <<'GSZ_CSS17'
/* ============================================================
   GALAXY SUBZ × ZAYRON — storefront design system (v2)
   Light, neutral-led, restrained brand accents. One system.
   ============================================================ */
:root{
  --paper:#fbfbfd; --surface:#ffffff; --ink:#0e1430; --muted:#6b7391;
  --line:#eceef5; --line-2:#e3e6f1;
  --v:#7a2bff; --b:#2a6cff; --c:#19c6ee;
  --brand:linear-gradient(100deg,#7a2bff,#2a6cff 55%,#19c6ee);
  --ink-soft:#2a3152; --wash:#f4f6fb;
  --ok:#12b26a; --warn:#e8a33d;
  --display:'Bricolage Grotesque',system-ui,sans-serif;
  --body:'Hanken Grotesk',system-ui,'Segoe UI',sans-serif;
  --wrap:1480px; --gut:clamp(16px,3vw,44px);
  --r:16px; --r-sm:11px; --r-lg:22px;
  --shadow:0 1px 2px rgba(14,20,48,.04),0 14px 34px -22px rgba(14,20,48,.26);
  --shadow-lg:0 2px 6px rgba(14,20,48,.05),0 30px 60px -30px rgba(14,20,48,.34);
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--body);
  font-size:16px;line-height:1.5;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
img{max-width:100%;display:block}
ul{margin:0;padding:0;list-style:none}
button{font-family:inherit}
.wrap{max-width:var(--wrap);margin:0 auto;padding:0 var(--gut)}
.ic{width:22px;height:22px;stroke:currentColor;fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.ic-sm{width:17px;height:17px}
.tnum{font-variant-numeric:tabular-nums}
.grad-text{background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}

/* ---- buttons ---- */
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;
  font-weight:600;font-size:15px;border:0;border-radius:12px;padding:12px 20px;cursor:pointer;
  transition:transform .15s ease,box-shadow .15s ease,background .15s ease;white-space:nowrap}
.btn-primary{background:var(--brand);color:#fff;box-shadow:0 12px 26px -12px rgba(42,108,255,.85)}
.btn-primary:hover{transform:translateY(-1px);box-shadow:0 16px 30px -12px rgba(42,108,255,.95)}
.btn-dark{background:var(--ink);color:#fff}
.btn-dark:hover{transform:translateY(-1px)}
.btn-ghost{background:var(--surface);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line-2)}
.btn-ghost:hover{box-shadow:inset 0 0 0 1.5px var(--b);color:var(--b)}
.btn-wa{background:#1fb457;color:#fff}
.btn-wa:hover{background:#19a04d;transform:translateY(-1px)}
.btn-lg{padding:15px 26px;font-size:16px;border-radius:14px}

/* ---- offer bar (no close button) ---- */
.offer{background:var(--ink);color:#fff;font-size:13.5px;overflow:hidden}
.offer-in{display:flex;align-items:center;gap:16px;height:40px;max-width:var(--wrap);margin:0 auto;padding:0 var(--gut)}
.marquee{flex:1;overflow:hidden;mask:linear-gradient(90deg,transparent,#000 6%,#000 94%,transparent)}
.marquee ul{display:flex;gap:40px;width:max-content;animation:marq 32s linear infinite}
.marquee li{display:flex;align-items:center;gap:8px;color:#cdd3ea;white-space:nowrap}
.marquee li svg{color:var(--c)}
@keyframes marq{to{transform:translateX(-50%)}}
.code-chip{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.1);color:#fff;
  border:0;border-radius:999px;padding:6px 13px;font-size:12.5px;font-weight:600;cursor:pointer;white-space:nowrap}
.code-chip b{letter-spacing:.04em}
.code-chip:hover{background:rgba(255,255,255,.18)}

/* ---- header ---- */
.hd{position:sticky;top:0;z-index:50;background:rgba(251,251,253,.86);backdrop-filter:blur(14px);
  border-bottom:1px solid transparent;transition:border-color .2s,box-shadow .2s}
.hd.scrolled{border-color:var(--line);box-shadow:0 10px 30px -24px rgba(14,20,48,.4)}
.hd-in{display:flex;align-items:center;gap:20px;height:76px}
.brand{display:flex;align-items:center;gap:9px;flex:none}
.brand img{height:40px;width:auto}
.wordmark{font-family:var(--display);font-weight:800;font-size:21px;letter-spacing:-.02em}
.nav{display:flex;align-items:center;gap:4px}
.nav a{padding:9px 13px;border-radius:9px;font-weight:600;font-size:15px;color:var(--ink-soft);transition:.15s}
.nav a:hover{background:var(--wash);color:var(--ink)}
.hd-search{flex:1;max-width:640px;min-width:240px;position:relative}
.hd-search input{width:100%;height:48px;border:1px solid var(--line-2);border-radius:13px;background:var(--surface);
  padding:0 16px 0 46px;font-size:15px;font-family:inherit;color:var(--ink)}
.hd-search input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent}
.hd-search .si{position:absolute;left:13px;top:50%;transform:translateY(-50%);color:var(--muted)}
.hd-sp{display:none}
.hd-tools{display:flex;align-items:center;gap:10px;flex:none;margin-left:auto}
.region{display:inline-flex;align-items:center;gap:7px;background:var(--surface);border:1px solid var(--line-2);
  border-radius:11px;padding:8px 11px;font-weight:600;font-size:13.5px;cursor:pointer;color:var(--ink)}
.region:hover{border-color:var(--b)}
.region .flag{width:18px;height:13px;border-radius:2px;object-fit:cover}
.pos-rel{position:relative}
.rmenu{position:absolute;right:0;top:calc(100% + 8px);background:var(--surface);border:1px solid var(--line);
  border-radius:12px;box-shadow:var(--shadow-lg);padding:6px;min-width:170px;display:none;z-index:60}
.rmenu.on{display:block}
.rmenu button{display:flex;align-items:center;gap:9px;width:100%;border:0;background:none;padding:9px 11px;
  border-radius:8px;font-weight:600;font-size:13.5px;cursor:pointer;color:var(--ink-soft)}
.rmenu button:hover{background:var(--wash)}
.rmenu button.on{color:var(--b)}
.rmenu .flag{width:18px;height:13px;border-radius:2px}
.icon-btn{display:inline-grid;place-items:center;width:44px;height:44px;border-radius:11px;background:var(--surface);
  border:1px solid var(--line-2);color:var(--ink);cursor:pointer;position:relative}
.icon-btn:hover{border-color:var(--b);color:var(--b)}
.burger{display:none}
.hd-wa .label{display:inline}

/* search dropdown (inline, no popup) */
.sresults{position:absolute;left:0;right:0;top:calc(100% + 8px);min-width:360px;background:var(--surface);border:1px solid var(--line);
  border-radius:14px;box-shadow:var(--shadow-lg);padding:6px;max-height:min(72vh,520px);overflow-y:auto;overflow-x:hidden;display:none;z-index:70}
.sresult .nm{white-space:normal;line-height:1.25}
.sresults.on{display:block}
.sresult{display:flex;align-items:center;gap:12px;padding:9px 11px;border-radius:10px}
.sresult:hover{background:var(--wash)}
.sresult .th{width:40px;height:40px;border-radius:9px;object-fit:cover;flex:none;background:var(--wash)}
.sresult .nm{font-weight:600;font-size:14px}
.sresult .mt{font-size:12.5px;color:var(--muted)}
.sresult .pr{margin-left:auto;font-weight:700;font-size:13.5px}
.sempty{padding:18px 12px;color:var(--muted);font-size:14px;text-align:center}

/* ---- hero (inset, rounded, shows the WHOLE banner — never cropped) ---- */
.hero{position:relative;width:100%;padding:clamp(12px,1.8vw,22px) var(--gut) 0}
.hero-stage{position:relative;width:100%;max-width:1760px;margin-inline:auto;overflow:hidden;border-radius:var(--r-lg);background:var(--wash);box-shadow:0 18px 50px -30px rgba(14,20,48,.5),0 1px 0 var(--line)}
.hslide{position:absolute;inset:0;opacity:0;transition:opacity .7s ease;pointer-events:none}
.hslide.on{position:relative;opacity:1;pointer-events:auto}
.hslide{display:block}
.hslide img,.hslide picture{width:100%;height:auto;display:block}
.hero-dots{position:absolute;right:var(--gut);bottom:18px;display:flex;gap:7px;z-index:3}
.hero-dots button{width:9px;height:9px;border-radius:999px;border:0;background:rgba(255,255,255,.45);cursor:pointer;padding:0}
.hero-dots button.on{background:#fff;width:24px}
.hero-ar{position:absolute;top:50%;transform:translateY(-50%);width:44px;height:44px;border-radius:999px;
  border:0;background:rgba(10,14,34,.42);color:#fff;display:grid;place-items:center;cursor:pointer;z-index:3}
.hero-ar:hover{background:rgba(10,14,34,.7)}
.hero-ar.prev{left:14px}.hero-ar.next{right:14px}
@media(max-width:720px){.hero{padding-top:10px}.hero-ar{display:none}}

/* ---- credibility stats ---- */
.stats{border-bottom:1px solid var(--line)}
.stats-in{display:grid;grid-template-columns:repeat(3,1fr);gap:0;padding:26px 0}
.stat{text-align:center;padding:4px 16px;position:relative}
.stat+.stat{border-left:1px solid var(--line)}
.stat b{display:block;font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,38px);letter-spacing:-.02em;line-height:1}
.stat .lbl{display:block;margin-top:7px;color:var(--muted);font-size:13.5px;font-weight:500}
.stat .star{color:#f5b301}
@media(max-width:560px){.stats-in{padding:18px 0}.stat{padding:4px 8px}.stat .lbl{font-size:12px}}

/* ---- section rhythm ---- */
.section{padding:clamp(26px,3.4vw,46px) 0}
.section.tint{background:var(--wash)}
/* immersive dark band — adds variety between categories */
.section.dark{background:radial-gradient(1200px 500px at 15% -10%,rgba(122,43,255,.5),transparent 60%),radial-gradient(1000px 500px at 110% 20%,rgba(25,198,238,.4),transparent 55%),#0b1030;color:#fff}
.section.dark .sec-head h2{color:#fff}
.section.dark .eyebrow{color:#c7cdea}
.section.dark .pcard{background:rgba(255,255,255,.06);border-color:rgba(255,255,255,.12);backdrop-filter:blur(6px)}
.section.dark .pcard .pname{color:#fff}
.section.dark .pcard .pdesc{color:#aab2d6}
.section.dark .pcard .pprice{color:#fff}
.section.dark .pcard .pfrom{color:#9aa3cc}
.section.dark .view-all{color:var(--c)}
.sec-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:30px}
.sec-head .eyebrow{display:inline-flex;align-items:center;gap:8px;font-weight:600;font-size:13.5px;color:var(--muted)}
.sec-head .eyebrow .dot{width:8px;height:8px;border-radius:999px;background:var(--brand)}
.sec-head h2{font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:6px 0 0;line-height:1.05}
.view-all{display:inline-flex;align-items:center;gap:6px;font-weight:600;font-size:14.5px;color:var(--b);flex:none}
.view-all:hover{text-decoration:underline}

/* ---- category grid ---- */
.catgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:14px}
.cat-tile{display:flex;align-items:center;gap:14px;background:var(--surface);border:1px solid var(--line);
  border-radius:var(--r);padding:16px;transform-style:preserve-3d;will-change:transform;
  transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .2s,border-color .2s}
.cat-tile:hover{box-shadow:0 20px 44px -22px rgba(42,108,255,.5);border-color:transparent}
.cat-tile .cg{transition:transform .2s cubic-bezier(.2,.7,.3,1)}
.cat-tile:hover .cg{transform:translateZ(22px) scale(1.05)}
.cat-tile .cg{width:46px;height:46px;border-radius:13px;display:grid;place-items:center;flex:none;color:#fff;
  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.cat-tile .cg svg{stroke:#fff}
.cat-tile b{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;display:block}
.cat-tile .n{color:var(--muted);font-size:13px}

/* ---- product grid + cards ---- */
.pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(212px,1fr));gap:18px}
.pgrid.g4{grid-template-columns:repeat(auto-fill,minmax(212px,1fr))}
@media(max-width:620px){.pgrid,.pgrid.g4{grid-template-columns:repeat(2,1fr);gap:12px}}
.pcard{position:relative;display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--line);
  border-radius:var(--r);overflow:hidden;transform-style:preserve-3d;will-change:transform;
  transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .25s ease,border-color .2s}
.pcard:hover{box-shadow:0 26px 60px -26px rgba(42,108,255,.55),0 2px 8px rgba(14,20,48,.06);border-color:transparent}
.pcard .pimg,.pcard .pfallback{transition:transform .55s cubic-bezier(.2,.7,.3,1)}
.pcard:hover .pimg,.pcard:hover .pfallback{transform:scale(1.07)}
.pcard::after{content:"";position:absolute;top:0;left:-60%;width:42%;height:100%;z-index:3;pointer-events:none;
  background:linear-gradient(100deg,transparent,rgba(255,255,255,.4),transparent);transform:skewX(-18deg);opacity:0}
.pcard:hover::after{opacity:1;animation:shine .9s ease forwards}
@keyframes shine{from{left:-60%}to{left:130%}}
.pcard .pimg{aspect-ratio:1/1;width:100%;object-fit:cover;background:var(--wash)}
.pcard .pfallback{aspect-ratio:1/1;width:100%;display:grid;place-items:center;position:relative;overflow:hidden;
  background:linear-gradient(145deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.pcard .pfallback span{font-family:var(--display);font-weight:800;color:#fff;font-size:30px;letter-spacing:-.02em;
  opacity:.95;text-align:center;padding:0 14px;line-height:1.05}
.pcard .pbody{padding:14px 15px 16px;display:flex;flex-direction:column;gap:4px;flex:1}
.pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2}
.pcard .pdesc{color:var(--muted);font-size:13.5px;line-height:1.45;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.pcard .pfoot{margin-top:auto;padding-top:12px;display:flex;align-items:baseline;gap:6px}
.pcard .pfrom{color:var(--muted);font-size:12px;font-weight:500}
.pcard .pprice{font-family:var(--display);font-weight:800;font-size:17px;letter-spacing:-.01em}

/* ---- reviews (single scrolling row) ---- */
.rev-grid{display:grid;grid-template-columns:300px 1fr;gap:24px;align-items:start}
@media(max-width:820px){.rev-grid{grid-template-columns:1fr}}
.tp-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:26px;align-self:start}
.tp-score{display:flex;align-items:baseline;gap:6px}
.tp-score b{font-family:var(--display);font-weight:800;font-size:46px;letter-spacing:-.02em;line-height:1}
.tp-score span{color:var(--muted);font-weight:600}
.stars{display:flex;gap:3px;margin:12px 0 10px;color:#f5b301}
.stars svg{width:20px;height:20px;fill:currentColor;stroke:none}
.tp-sub{color:var(--muted);font-size:13.5px}
.tp-logo{display:flex;align-items:center;gap:7px;margin-top:16px;font-weight:700;font-size:15px}
.tp-logo svg{width:20px;height:20px;fill:#12b26a;stroke:none}
.rev-cards{display:flex;gap:16px;overflow-x:auto;padding:6px 2px 14px;scroll-snap-type:x mandatory;scrollbar-width:thin}
.rev-cards::-webkit-scrollbar{height:7px}
.rev-cards::-webkit-scrollbar-thumb{background:var(--line-2);border-radius:999px}
.rev{flex:0 0 300px;scroll-snap-align:start;background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:18px;
  transform-style:preserve-3d;will-change:transform;transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .25s}
.rev:hover{box-shadow:0 26px 56px -28px rgba(42,108,255,.5);border-color:transparent}
@media(max-width:520px){.rev{flex-basis:84vw}}
.rev .rs{display:flex;gap:2px;color:#f5b301;margin-bottom:9px}
.rev .rs svg{width:15px;height:15px;fill:currentColor;stroke:none}
.rev p{margin:0 0 14px;font-size:14.5px;line-height:1.5;color:var(--ink-soft)}
.rev .who{display:flex;align-items:center;gap:10px}
.rev .av{width:34px;height:34px;border-radius:999px;display:grid;place-items:center;color:#fff;font-weight:700;font-size:13px;background:var(--brand)}
.rev .who b{font-size:13.5px;display:block}
.rev .who span{font-size:12px;color:var(--muted)}

/* ---- brand family ---- */
.house{border-top:1px solid var(--line);border-bottom:1px solid var(--line);background:var(--surface)}
.house-in{display:flex;align-items:center;gap:22px;flex-wrap:wrap;padding:22px 0}
.house .lbl{display:inline-flex;align-items:center;gap:8px;color:var(--muted);font-size:13.5px;font-weight:600}
.house .lbl svg{color:var(--ok)}
.brands{display:flex;gap:10px;flex-wrap:wrap}
.brands a{font-family:var(--display);font-weight:700;font-size:15px;color:var(--ink-soft);
  padding:7px 14px;border-radius:999px;background:var(--wash)}
.brands a:hover{color:var(--b)}

/* ---- footer ---- */
.ft{background:var(--ink);color:#c7cdea;padding:56px 0 30px}
.ft-top{display:grid;grid-template-columns:1.6fr 1fr 1fr 1fr;gap:34px}
@media(max-width:820px){.ft-top{grid-template-columns:1fr 1fr}}
@media(max-width:520px){.ft-top{grid-template-columns:1fr}}
.ft-brand img{height:38px;margin-bottom:12px}
.ft-brand .wordmark{color:#fff}
.ft-brand p{font-size:14px;line-height:1.55;max-width:38ch;margin:10px 0 16px}
.social{display:flex;gap:10px}
.social a{width:38px;height:38px;border-radius:10px;display:grid;place-items:center;background:rgba(255,255,255,.07);color:#fff}
.social a:hover{background:var(--brand)}
.ft-col h4{color:#fff;font-family:var(--display);font-size:14px;font-weight:700;margin:0 0 14px;letter-spacing:.01em}
.ft-col a{display:block;font-size:14px;padding:5px 0;color:#aab2d6}
.ft-col a:hover{color:#fff}
.ft-bottom{display:flex;align-items:center;justify-content:space-between;gap:14px;flex-wrap:wrap;
  margin-top:36px;padding-top:22px;border-top:1px solid rgba(255,255,255,.1);font-size:13px}
.pays{display:flex;gap:8px;flex-wrap:wrap}
.pay{background:rgba(255,255,255,.07);border-radius:7px;padding:5px 11px;font-size:12.5px;font-weight:600;color:#cdd3ea}

/* ---- drawer (mobile) ---- */
.scrim-el{position:fixed;inset:0;background:rgba(10,14,34,.5);opacity:0;pointer-events:none;transition:.25s;z-index:80}
.scrim-el.on{opacity:1;pointer-events:auto}
.drawer{position:fixed;top:0;right:0;bottom:0;width:min(86vw,340px);background:var(--surface);z-index:90;
  transform:translateX(100%);transition:transform .28s ease;display:flex;flex-direction:column;padding:18px}
.drawer.on{transform:none}
.drawer-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}
.drawer-top img{height:34px}
.drawer-cats{display:flex;flex-direction:column;gap:4px;margin:8px 0}
.dcat{display:flex;align-items:center;gap:12px;border:0;background:none;padding:11px 10px;border-radius:11px;cursor:pointer;text-align:left;color:var(--ink)}
.dcat:hover{background:var(--wash)}
.dcat .cg{width:38px;height:38px;border-radius:10px;display:grid;place-items:center;color:#fff;flex:none;
  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.dcat b{font-weight:700;font-size:14.5px}
.dcat .n{font-size:12px;color:var(--muted)}
.drawer-foot{margin-top:auto;padding-top:14px;border-top:1px solid var(--line);display:flex;flex-direction:column;gap:12px}
.drawer-region{display:flex;gap:8px}
.drawer-region button{flex:1;border:1px solid var(--line-2);background:var(--surface);border-radius:9px;padding:9px;font-weight:600;cursor:pointer;color:var(--ink-soft)}
.drawer-region button.on{border-color:var(--b);color:var(--b)}

/* ---- toss (social proof popup) ---- */
.toss{position:fixed;left:18px;bottom:18px;z-index:70;display:flex;align-items:center;gap:12px;
  background:var(--surface);border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow-lg);
  padding:11px 14px;max-width:320px;cursor:pointer;transform:translateY(140%);transition:transform .4s cubic-bezier(.2,.7,.3,1);text-align:left}
.toss.on{transform:none}
.toss .tt{width:44px;height:44px;border-radius:11px;display:grid;place-items:center;color:#fff;font-weight:800;flex:none;background:var(--brand);overflow:hidden}
.toss .tt-img{padding:0}
.toss .tt img{width:100%;height:100%;object-fit:cover;border-radius:11px}
.toss .tb b{font-size:13.5px;display:block}
.toss .tb span{font-size:12px;color:var(--muted)}
.toss .tx{position:absolute;top:-8px;right:-8px;width:22px;height:22px;border-radius:999px;background:var(--ink);
  color:#fff;border:0;display:grid;place-items:center;cursor:pointer;font-size:12px}

/* ---- toast ---- */
.toast{position:fixed;left:50%;bottom:26px;transform:translateX(-50%) translateY(140%);z-index:95;
  background:var(--ink);color:#fff;border-radius:12px;padding:12px 18px;font-size:14px;font-weight:500;
  box-shadow:var(--shadow-lg);transition:transform .3s;max-width:90vw}
.toast.on{transform:translateX(-50%)}

/* ---- currency modal (world currencies) ---- */
.cur-modal{position:fixed;inset:0;z-index:120;display:none}
.cur-modal.on{display:block}
.cur-backdrop{position:absolute;inset:0;background:rgba(10,14,34,.55);backdrop-filter:blur(3px);animation:fade .2s ease}
@keyframes fade{from{opacity:0}to{opacity:1}}
.cur-sheet{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:min(560px,92vw);max-height:84vh;
  background:var(--surface);border:1px solid var(--line);border-radius:18px;box-shadow:var(--shadow-lg);
  display:flex;flex-direction:column;overflow:hidden;animation:pop .22s cubic-bezier(.2,.7,.3,1)}
@keyframes pop{from{opacity:0;transform:translate(-50%,-46%) scale(.97)}to{opacity:1;transform:translate(-50%,-50%) scale(1)}}
.cur-head{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;padding:20px 20px 14px}
.cur-head h3{font-family:var(--display);font-weight:800;font-size:19px;letter-spacing:-.01em;margin:0}
.cur-head p{margin:4px 0 0;color:var(--muted);font-size:13px}
.cur-x{flex:none;width:36px;height:36px;border-radius:10px;border:1px solid var(--line-2);background:var(--surface);color:var(--ink);cursor:pointer;display:grid;place-items:center}
.cur-x:hover{border-color:var(--b);color:var(--b)}
.cur-search{position:relative;margin:0 20px 12px}
.cur-search svg{position:absolute;left:13px;top:50%;transform:translateY(-50%);color:var(--muted)}
.cur-search input{width:100%;height:46px;border:1px solid var(--line-2);border-radius:12px;background:var(--wash);
  padding:0 14px 0 42px;font-size:15px;font-family:inherit;color:var(--ink)}
.cur-search input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent;background:var(--surface)}
.cur-list{overflow-y:auto;padding:0 12px 14px;display:grid;grid-template-columns:1fr 1fr;gap:6px}
@media(max-width:520px){.cur-list{grid-template-columns:1fr}}
.cur-item{display:flex;align-items:center;gap:10px;width:100%;border:1px solid transparent;background:none;
  padding:10px 11px;border-radius:11px;cursor:pointer;text-align:left;color:var(--ink);transition:.12s}
.cur-item:hover{background:var(--wash)}
.cur-item.on{border-color:var(--b);background:color-mix(in srgb,var(--b) 8%,#fff)}
.cur-item .flag{width:22px;height:16px;border-radius:3px;object-fit:cover;flex:none}
.cur-item .cc{font-weight:800;font-size:13.5px;font-family:var(--display);width:40px;flex:none}
.cur-item .cn{font-size:13px;color:var(--ink-soft);flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cur-item .cs{font-size:12.5px;color:var(--muted);font-weight:600;flex:none}

/* ---- responsive header ---- */
@media(max-width:1040px){
  .nav{display:none}
  .hd-search{max-width:none}
}
@media(max-width:760px){
  .hd-in{height:auto;min-height:64px;gap:10px;flex-wrap:wrap;padding:10px 0}
  .hd-search{display:block;order:5;flex-basis:100%;max-width:none}
  .hd-sp{display:none}
  .hd-wa .label{display:none}
  .hd-wa{padding:0;width:44px;height:44px;border-radius:11px}
  .burger{display:inline-grid}
  .region{display:none}
}

/* ============================================================
   MOTION & DEPTH — scroll reveal, button shine
   (3D tilt + hero parallax handled in app.js; reduced-motion safe)
   ============================================================ */
.gsz-js .reveal{opacity:0;transform:translateY(26px);transition:opacity .7s ease,transform .7s cubic-bezier(.2,.7,.3,1)}
.gsz-js .reveal.in{opacity:1;transform:none}
.btn-primary{position:relative;overflow:hidden}
.btn-primary::after{content:"";position:absolute;top:0;left:-70%;width:40%;height:100%;pointer-events:none;
  background:linear-gradient(100deg,transparent,rgba(255,255,255,.4),transparent);transform:skewX(-18deg);opacity:0}
.btn-primary:hover::after{opacity:1;animation:shine .8s ease forwards}

/* animated gradient numbers (count-up) */
.gradnum{background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent;background-size:200% 100%;animation:hue 6s linear infinite;font-variant-numeric:tabular-nums}
.stat .star{color:#f5b301}
@keyframes hue{to{background-position:200% 0}}
/* gradient ring on category tiles for depth */
.cat-tile{position:relative;isolation:isolate}
.cat-tile::before{content:"";position:absolute;inset:-1px;border-radius:inherit;padding:1px;background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee));-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude;opacity:0;transition:opacity .2s;z-index:-1}
.cat-tile:hover::before{opacity:1}
/* eyebrow dot pulse */
.sec-head .eyebrow .dot{box-shadow:0 0 0 0 rgba(42,108,255,.5);animation:pulse 2.6s ease-out infinite}
@keyframes pulse{0%{box-shadow:0 0 0 0 rgba(42,108,255,.45)}70%{box-shadow:0 0 0 7px rgba(42,108,255,0)}100%{box-shadow:0 0 0 0 rgba(42,108,255,0)}}

@media(prefers-reduced-motion:reduce){
  .gradnum{animation:none}
  .sec-head .eyebrow .dot{animation:none}
  .reveal{opacity:1;transform:none;transition:none}
}
@media(prefers-reduced-motion:reduce){
  *{animation-duration:.001ms !important;transition-duration:.001ms !important}
  .marquee ul{animation:none}
}

/* ============================================================
   PRODUCT PAGE (PDP)
   ============================================================ */
.pdp{padding:clamp(26px,4vw,46px) 0}
.pdp-top{display:grid;grid-template-columns:1fr 1fr;gap:clamp(22px,4vw,48px);align-items:start}
@media(max-width:860px){.pdp-top{grid-template-columns:1fr}}
.pdp-media{position:relative;border-radius:var(--r-lg);overflow:hidden;aspect-ratio:1/1;background:var(--wash);
  box-shadow:var(--shadow-lg);transform-style:preserve-3d;will-change:transform;transition:transform .2s cubic-bezier(.2,.7,.3,1)}
.pdp-media img{width:100%;height:100%;object-fit:cover}
.pdp-media .pf{width:100%;height:100%;display:grid;place-items:center;color:#fff;font-family:var(--display);
  font-weight:800;font-size:clamp(28px,5vw,46px);letter-spacing:-.02em;text-align:center;padding:24px;line-height:1.05;
  background:linear-gradient(145deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.pdp-info .crumbs{font-size:13px;color:var(--muted);margin-bottom:12px}
.pdp-info .crumbs a{color:var(--muted)}
.pdp-info .crumbs a:hover{color:var(--b)}
.pdp-info h1{font-family:var(--display);font-weight:800;font-size:clamp(28px,4vw,42px);letter-spacing:-.02em;margin:0 0 12px;line-height:1.04}
.pdp-meta{display:flex;align-items:center;gap:16px;color:var(--muted);font-size:14px;margin-bottom:18px;flex-wrap:wrap}
.pdp-meta .rt{display:inline-flex;align-items:center;gap:5px;color:#1d2340;font-weight:700}
.pdp-meta .rt .star{color:#f5b301}
.pdp-meta .chip{display:inline-flex;align-items:center;gap:6px;background:var(--wash);border-radius:999px;padding:5px 11px;font-size:12.5px;font-weight:600;color:var(--ink-soft)}
.pdp-lead{font-size:15.5px;color:var(--ink-soft);line-height:1.6;margin:0 0 24px;max-width:52ch}
.plans{display:flex;flex-direction:column;gap:10px;margin-bottom:22px}
.plan{display:flex;align-items:center;gap:14px;border:1.5px solid var(--line-2);border-radius:13px;padding:14px 16px;cursor:pointer;background:var(--surface);transition:.15s}
.plan:hover{border-color:var(--b)}
.plan.sel{border-color:var(--b);box-shadow:0 0 0 3px rgba(42,108,255,.12)}
.plan .rdo{width:20px;height:20px;border-radius:50%;border:2px solid var(--line-2);flex:none;display:grid;place-items:center}
.plan.sel .rdo:after{content:"";width:10px;height:10px;border-radius:50%;background:var(--b)}
.plan .pl{font-weight:600;font-size:15px;flex:1}
.plan .pp{font-family:var(--display);font-weight:800;font-size:17px;white-space:nowrap}
.plan .pp .was{font-size:12.5px;color:var(--muted);text-decoration:line-through;font-weight:500;margin-right:6px}
.buyrow{display:flex;gap:12px;flex-wrap:wrap}
.buyrow .btn{flex:1;min-width:150px}
.tchips{display:flex;gap:9px;flex-wrap:wrap;margin-top:20px}
.tchips span{display:inline-flex;align-items:center;gap:7px;font-size:12.5px;color:var(--ink-soft);background:var(--wash);border-radius:999px;padding:8px 13px}
.tchips svg{color:var(--b)}
.pdp-sec{padding:clamp(30px,4vw,48px) 0;border-top:1px solid var(--line)}
.pdp-sec h2{font-family:var(--display);font-weight:800;font-size:clamp(20px,2.4vw,26px);letter-spacing:-.01em;margin:0 0 18px}
.longdesc{color:var(--ink-soft);line-height:1.75;max-width:72ch;white-space:pre-wrap;font-size:15.5px}
.faq details{border:1px solid var(--line);border-radius:12px;margin-bottom:10px;background:var(--surface);overflow:hidden}
.faq summary{padding:15px 18px;font-weight:600;font-size:15px;cursor:pointer;list-style:none;display:flex;justify-content:space-between;align-items:center;gap:14px}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:"+";font-size:22px;color:var(--muted);line-height:1}
.faq details[open] summary::after{content:"\2013"}
.faq p{margin:0;padding:0 18px 16px;color:var(--ink-soft);line-height:1.65}

GSZ_CSS17

cat > "$APP/views/partials/store_top.ejs" <<'GSZ_TOP17'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title><%= typeof title!=='undefined' ? title : siteName %></title>
<link rel="icon" href="/static/img/<%= logoFile %>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,600;12..96,700;12..96,800&family=Hanken+Grotesk:wght@400;500;600;700&display=swap">
<link rel="stylesheet" href="/static/css/app.css?v=9">
</head>
<body>

<!-- OFFER BAR (always on, no close button) -->
<div class="offer">
  <div class="offer-in">
    <div class="marquee" aria-hidden="true"><ul id="marqueeList"></ul></div>
    <button class="code-chip" id="codeChip" title="Copy code">
      <svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/></svg>
      SAVE 10% <b>GALAXY10</b></button>
  </div>
</div>

<!-- HEADER (universal) -->
<header class="hd" id="hd">
  <div class="wrap hd-in">
    <a href="/" class="brand" aria-label="<%= siteName %> — home">
      <img src="/static/img/<%= logoFile %>" alt="<%= siteName %>" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'">
      <span class="wordmark" style="display:none;align-items:center;gap:6px">Galaxy&nbsp;Subz <span class="grad-text">× Zayron</span></span>
    </a>
    <nav class="nav" aria-label="Primary">
      <% cats.slice(0,5).forEach(function(c){ %><a href="/category/<%= c.slug %>"><%= c.name %></a><% }); %>
      <a href="/resellers">Resellers</a>
    </nav>
    <div class="hd-search">
      <svg class="ic ic-sm si" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
      <input id="searchInput" type="text" placeholder="Search Netflix, IPTV, VPN, Canva…" autocomplete="off" aria-label="Search products">
      <div class="sresults" id="searchRes"></div>
    </div>
    <div class="hd-sp"></div>
    <div class="hd-tools">
      <button class="region" id="curBtn" aria-haspopup="dialog">
        <img class="flag" id="curFlag" src="" alt=""><span id="curLabel">PKR</span>
        <svg class="ic ic-sm" viewBox="0 0 24 24" style="opacity:.5"><path d="m6 9 6 6 6-6"/></svg>
      </button>
      <a class="btn btn-wa hd-wa" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener">
        <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg><span class="label">Order on WhatsApp</span></a>
      <button class="icon-btn burger" id="burger" aria-label="Menu"><svg class="ic" viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18"/></svg></button>
    </div>
  </div>
</header>

GSZ_TOP17

cat > "$APP/views/partials/store_bottom.ejs" <<'GSZ_BOT17'
<!-- BRAND FAMILY -->
<div class="house">
  <div class="wrap house-in">
    <span class="lbl"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>One trusted family of brands</span>
    <div class="brands">
      <a href="https://galaxytools.net" target="_blank" rel="noopener">galaxytools.net</a>
      <a href="https://galaxy-tools.com" target="_blank" rel="noopener">galaxy-tools.com</a>
      <a href="https://zayron.tv" target="_blank" rel="noopener">zayron.tv</a>
      <a href="https://zayron.pro" target="_blank" rel="noopener">zayron.pro</a>
    </div>
  </div>
</div>

<!-- FOOTER -->
<footer class="ft">
  <div class="wrap">
    <div class="ft-top">
      <div class="ft-brand">
        <img src="/static/img/<%= logoFile %>" alt="<%= siteName %>" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'">
        <span class="wordmark" style="display:none;align-items:center;gap:6px">Galaxy&nbsp;Subz <span class="grad-text">× Zayron</span></span>
        <p>Premium digital subscriptions and IPTV, delivered fast and backed by real support — one trusted home for streaming, tools, VPNs and players.</p>
        <div class="social">
          <a href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener" aria-label="WhatsApp"><svg class="ic" viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg></a>
          <a href="#" data-toast="Instagram link — set in admin." aria-label="Instagram"><svg class="ic" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"/></svg></a>
          <a href="#" data-toast="Facebook link — set in admin." aria-label="Facebook"><svg class="ic" viewBox="0 0 24 24"><path d="M14 9h3V5h-3c-2.2 0-4 1.8-4 4v2H7v4h3v6h4v-6h3l1-4h-4V9c0-.6.4-1 1-1Z"/></svg></a>
          <a href="#" data-toast="Telegram link — set in admin." aria-label="Telegram"><svg class="ic" viewBox="0 0 24 24"><path d="m21 4-9 16-2.5-6.5L3 11l18-7Z"/><path d="M9.5 13.5 21 4"/></svg></a>
        </div>
      </div>
      <div class="ft-col"><h4>Shop</h4>
        <% cats.slice(0,6).forEach(function(c){ %><a href="/category/<%= c.slug %>"><%= c.name %></a><% }); %>
      </div>
      <div class="ft-col"><h4>Company</h4>
        <a href="/about">About us</a>
        <a href="/resellers">Reseller panels</a>
        <a href="#" data-toast="Blog — coming soon.">Blog</a>
        <a href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener">Contact</a>
      </div>
      <div class="ft-col"><h4>Support</h4>
        <a href="#" data-toast="Order lookup — coming soon.">Track an order</a>
        <a href="#" data-toast="IPTV tools — coming soon.">Check line status</a>
        <a href="#" data-toast="Renewals — coming soon.">Renew IPTV</a>
        <a href="#" data-toast="FAQ — coming soon.">FAQ &amp; policies</a>
      </div>
    </div>
    <div class="ft-bottom">
      <span>© <%= new Date().getFullYear() %> <%= siteName %>. All rights reserved.</span>
      <div class="pays"><span class="pay">Pakistani banks</span><span class="pay">Binance</span><span class="pay">TapTap</span></div>
    </div>
  </div>
</footer>

<!-- MOBILE DRAWER -->
<div class="scrim-el" id="scrim"></div>
<aside class="drawer" id="drawer" aria-label="Menu">
  <div class="drawer-top">
    <img src="/static/img/<%= logoFile %>" alt="<%= siteName %>" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'">
    <span class="wordmark" style="display:none;align-items:center;gap:6px">Galaxy&nbsp;Subz <span class="grad-text">× Zayron</span></span>
    <button class="icon-btn" id="drawerX" aria-label="Close"><svg class="ic" viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
  </div>
  <div class="drawer-cats" id="drawerCats"></div>
  <div class="drawer-foot">
    <button class="btn btn-ghost" id="drawerCurrency" type="button" style="width:100%">Change currency</button>
    <a class="btn btn-wa" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Order on WhatsApp</a>
  </div>
</aside>

<!-- CURRENCY MODAL (world currencies) -->
<div class="cur-modal" id="curModal" aria-hidden="true">
  <div class="cur-backdrop" id="curBackdrop"></div>
  <div class="cur-sheet" role="dialog" aria-label="Choose your currency">
    <div class="cur-head">
      <div><h3>Choose your currency</h3><p>Prices update instantly — you still check out securely.</p></div>
      <button class="cur-x" id="curClose" type="button" aria-label="Close"><svg class="ic" viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
    </div>
    <div class="cur-search">
      <svg class="ic ic-sm" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
      <input id="curSearch" type="text" placeholder="Search by name or code…" autocomplete="off" aria-label="Search currency">
    </div>
    <div class="cur-list" id="curList"></div>
  </div>
</div>

<button class="toss" id="toss" style="display:none"></button>
<div class="toast" id="toast"></div>

<script>window.__DATA = <%- shellJson %>;</script>
<script src="/static/js/app.js?v=9" defer></script>
</body>
</html>

GSZ_BOT17

cat > "$APP/views/resellers.ejs" <<'GSZ_RES17'
<%- include('partials/store_top') %>
<% var waLink = waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent('Hi! I want an IPTV reseller panel.')) : '#'; %>

<section class="section">
  <div class="wrap" style="max-width:900px">
    <span class="eyebrow"><span class="dot"></span>IPTV reseller panels</span>
    <h1 style="font-family:var(--display);font-weight:800;font-size:clamp(30px,5vw,52px);letter-spacing:-.025em;line-height:1.03;margin:10px 0 18px">
      Run your own IPTV business with your own panel.
    </h1>
    <p style="font-size:17px;line-height:1.7;color:var(--ink-soft);max-width:62ch">
      We set you up with a reseller panel for premium IPTV servers — your own credits, your own prices, your own customers.
      Create and renew lines yourself, top up credits whenever you need, and keep every rupee of your margin. Free trials on
      every server, set up by hand and backed by real people on WhatsApp. No lock-in.
    </p>
    <div style="margin-top:26px;display:flex;gap:12px;flex-wrap:wrap">
      <a class="btn btn-primary btn-lg" href="<%= waLink %>" target="_blank" rel="noopener">Get your panel</a>
      <a class="btn btn-ghost btn-lg" href="/category/iptv">See the IPTV servers</a>
    </div>
  </div>
</section>

<section class="section tint">
  <div class="wrap">
    <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>What you get</span><h2>Everything to resell IPTV</h2></div></div>
    <div class="pgrid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr))">
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Your own credits</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Each panel has its own credit balance. Top up any time and spend credits only when you create or renew a line.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Create &amp; renew lines</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Make new subscriptions and renew existing ones yourself, instantly, without waiting on anyone.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Set your own prices</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">You decide what to charge your customers. Our reseller credit price is low, so your margin is yours to keep.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Multiple servers</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Panels for several premium IPTV servers — pick the ones that work best for your customers' regions and devices.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Free trials</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Test any server with a free trial before you commit — and let your own customers try before they buy.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Real support, no lock-in</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Setup help and honest answers on WhatsApp whenever you need them. Stay because it works, not because you're stuck.</p>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="wrap">
    <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>How it works</span><h2>Up and running in three steps</h2></div></div>
    <div class="pgrid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr))">
      <div class="pcard" style="padding:24px">
        <div style="font-family:var(--display);font-weight:800;font-size:30px;color:var(--b);margin-bottom:8px">1</div>
        <h3 style="font-family:var(--display);font-weight:800;font-size:17px;margin:0 0 6px">Message us on WhatsApp</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Tell us which server(s) you want. We'll recommend the best fit and send a free trial.</p>
      </div>
      <div class="pcard" style="padding:24px">
        <div style="font-family:var(--display);font-weight:800;font-size:30px;color:var(--b);margin-bottom:8px">2</div>
        <h3 style="font-family:var(--display);font-weight:800;font-size:17px;margin:0 0 6px">Get your panel &amp; credits</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">We hand over your reseller panel login and load your first credits. You're ready to sell.</p>
      </div>
      <div class="pcard" style="padding:24px">
        <div style="font-family:var(--display);font-weight:800;font-size:30px;color:var(--b);margin-bottom:8px">3</div>
        <h3 style="font-family:var(--display);font-weight:800;font-size:17px;margin:0 0 6px">Sell &amp; grow</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Create lines, set your prices, and top up credits as you grow. Better rates as your volume rises.</p>
      </div>
    </div>
  </div>
</section>

<section class="section tint">
  <div class="wrap" style="text-align:center">
    <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:0 0 10px">Ready to start your IPTV panel?</h2>
    <p style="color:var(--muted);margin:0 0 22px">Message us on WhatsApp — we'll set you up with a free trial and your reseller pricing.</p>
    <a class="btn btn-wa btn-lg" href="<%= waLink %>" target="_blank" rel="noopener">
      <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Get your IPTV panel
    </a>
  </div>
</section>

<%- include('partials/store_bottom') %>

GSZ_RES17

cat > /tmp/gsz17_bump.js <<'GSZ_BUMP17'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=17');fs.writeFileSync(f,s);
});
console.log('[ok] asset version -> v=17');
GSZ_BUMP17
node /tmp/gsz17_bump.js || { restore; exit 1; }
echo "[ok] files written"

pm2 restart gsz --update-env >/dev/null
sleep 2
OKALL=1
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")
HOME_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
RES_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/resellers")
HB=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
RES=$(curl -fsS "http://127.0.0.1:$PORT/resellers" || true)
JS=$(curl -fsS "http://127.0.0.1:$PORT/static/js/app.js?v=17" || true)
[ "$HEALTH" = "200" ]                   || { echo "FAIL: health $HEALTH"; OKALL=0; }
[ "$HOME_CODE" = "200" ]                 || { echo "FAIL: home $HOME_CODE"; OKALL=0; }
[ "$RES_CODE" = "200" ]                  || { echo "FAIL: /resellers $RES_CODE"; OKALL=0; }
grep -q 'id="curBtn"'   <<< "$HB"        || { echo "FAIL: currency button missing"; OKALL=0; }
grep -q 'id="curModal"' <<< "$HB"        || { echo "FAIL: currency modal missing"; OKALL=0; }
grep -q 'app.js?v=17'   <<< "$HB"        || { echo "FAIL: version not bumped"; OKALL=0; }
grep -q 'function setCurrency' <<< "$JS" || { echo "FAIL: currency JS missing"; OKALL=0; }
grep -q '/category/iptv' <<< "$RES"      || { echo "FAIL: resellers IPTV link missing"; OKALL=0; }
if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 20 --nostream || true; exit 1; fi
echo "============================================================"
echo "  STEP 17 OK — hard-refresh once (Ctrl+Shift+R)"
echo "  - Currency popup: click the currency (top-right) -> search 40+"
echo "    world currencies; prices repaint live (live rates + fallback)."
echo "  - Resellers page is now IPTV reseller panels only."
echo "============================================================"
