'use strict';
/* Top offer bar = fully announcement-driven.
   - Only posted GENERAL announcements show (no hardcoded fallback / stored lines).
   - The scrolling marquee shows each announcement's full message: <b>title</b> — body
     (NO coupon inside the moving marquee — a scrolling code can't be tapped).
   - The coupon is pinned as a STATIC, always-visible, copy-on-tap pill (#codeChip) at the
     right of the bar, so it "must show" on top and stays easy to copy.
   - The bar hides only when there are no announcements AND no coupon chip.
   Edits public/js/app.js (buildMarquee) + public/css/app.css (#codeChip; removes old .mq-code).
   buildMarquee is always replaced (re-appliable); CSS add/cleanup is guarded. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_marqueeonly.js <ROOT>'); process.exit(1); }

/* ---- app.js: replace the whole buildMarquee() ---- */
(function () {
  const file = path.join(ROOT, 'public/js/app.js');
  let s = fs.readFileSync(file, 'utf8');
  const START = 'function buildMarquee(){';
  const END_MARKER = '\n\n/* ---------- drawer ---------- */';
  const a = s.indexOf(START);
  if (a < 0) throw new Error('ANCHOR MISS: buildMarquee start');
  const b = s.indexOf(END_MARKER, a);
  if (b < 0) throw new Error('ANCHOR MISS: drawer marker after buildMarquee');

  const NEWFN =
"function buildMarquee(){ /*annOnly*/\n" +
"  var el=$('#marqueeList'); if(!el)return;\n" +
"  var offer=document.querySelector('.offer');\n" +
"  var inWrap=document.querySelector('.offer-in');\n" +
"  var mqIcons=['<path d=\"M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z\"/>','<path d=\"M13 2 4 14h6l-1 8 9-12h-6l1-8Z\"/>','<path d=\"m12 3 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 18l-5.2 2.9 1-5.8L3.5 9l5.9-.9Z\"/>','<rect x=\"3\" y=\"5\" width=\"18\" height=\"12\" rx=\"2\"/><path d=\"M8 21h8M12 17v4\"/>','<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 7v5l3 2\"/>','<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"m8 12 3 3 5-6\"/>'];\n" +
"  function esc(x){var d=document.createElement('div');d.textContent=(x==null?'':String(x));return d.innerHTML;}\n" +
"  function setChip(code){ var chip=document.getElementById('codeChip');\n" +
"    if(!code){ if(chip) chip.remove(); return; }\n" +
"    if(!chip){ chip=document.createElement('button'); chip.id='codeChip'; chip.type='button'; chip.setAttribute('aria-label','Copy coupon code');\n" +
"      chip.addEventListener('click',function(e){ e.preventDefault(); e.stopPropagation(); var c=chip.getAttribute('data-code')||''; if(!c)return; try{navigator.clipboard.writeText(c);}catch(err){} var lbl=chip.querySelector('.cc-t'); if(lbl){ var o=lbl.getAttribute('data-code')||lbl.textContent; lbl.textContent='Copied \\u2713'; setTimeout(function(){ lbl.textContent=o; },1300); } });\n" +
"      if(inWrap) inWrap.appendChild(chip); }\n" +
"    chip.setAttribute('data-code',code);\n" +
"    chip.innerHTML='<span class=\"cc-ic\">\\uD83C\\uDF9F</span><span class=\"cc-t\" data-code=\"'+esc(code)+'\">'+esc(code)+'</span>';\n" +
"  }\n" +
"  function hideBar(){ el.innerHTML=''; if(offer && !document.getElementById('codeChip')) offer.style.display='none'; }\n" +
"  fetch('/api/announcements',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():null;}).then(function(d){\n" +
"    var ann=((d&&d.items)||[]).filter(function(a){return !a.product;});\n" +
"    var coded=ann.filter(function(a){return a.coupon;});\n" +
"    setChip(coded.length?String(coded[0].coupon).trim():'');\n" +
"    if(!ann.length){ hideBar(); return; }\n" +
"    if(offer) offer.style.display='';\n" +
"    var row=ann.map(function(a,i){ var t=esc(String(a.title||'').trim()); var bd=esc(String(a.body||'').trim()); var msg=(t?('<b>'+t+'</b>'):'')+((t&&bd)?' — ':'')+(bd||''); if(!msg)msg='New update'; return '<li><svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\">'+mqIcons[i%mqIcons.length]+'</svg>'+msg+'</li>'; }).join('');\n" +
"    el.innerHTML=row+row;\n" +
"  }).catch(function(){ hideBar(); });\n" +
"}";

  s = s.slice(0, a) + NEWFN + s.slice(b);
  fs.writeFileSync(file, s);
  console.log('ANNOUNCEMENT MARQUEE + PINNED COUPON (app.js) OK');
})();

/* ---- app.css: pinned #codeChip pill; remove any stale .mq-code chip ---- */
(function () {
  const file = path.join(ROOT, 'public/css/app.css');
  let s = fs.readFileSync(file, 'utf8');
  // cleanup from the earlier in-marquee experiment
  const MQ = '\n.mq-code{display:inline-flex;align-items:center;gap:4px;margin-left:8px;padding:2px 10px;border-radius:999px;background:rgba(255,255,255,.22);border:1px solid rgba(255,255,255,.3);color:#fff;font-weight:800;letter-spacing:.3px;cursor:pointer;white-space:nowrap}';
  const HOVER = '\n.marquee ul:hover{animation-play-state:paused}';
  if (s.indexOf(MQ) >= 0) { s = s.replace(MQ, ''); }
  if (s.indexOf(HOVER) >= 0) { s = s.replace(HOVER, ''); }

  if (s.indexOf('#codeChip{') < 0) {
    const ANCHOR = '.marquee li svg{color:var(--c)}';
    const i = s.indexOf(ANCHOR);
    if (i < 0) throw new Error('ANCHOR MISS: .marquee li svg');
    const ADD = ANCHOR +
      '\n#codeChip{flex:none;display:inline-flex;align-items:center;gap:5px;padding:4px 13px;border:0;border-radius:999px;background:#fff;color:#4a21c7;font-family:inherit;font-weight:800;font-size:12.5px;letter-spacing:.3px;line-height:1;cursor:pointer;white-space:nowrap;box-shadow:0 3px 12px -3px rgba(0,0,0,.35);transition:transform .1s}' +
      '\n#codeChip:active{transform:translateY(1px)}' +
      '\n#codeChip .cc-ic{font-size:13px;line-height:1}' +
      '\n#codeChip .cc-t{min-width:0}';
    s = s.slice(0, i) + ADD + s.slice(i + ANCHOR.length);
    fs.writeFileSync(file, s);
    console.log('CODECHIP CSS OK');
  } else {
    fs.writeFileSync(file, s);
    console.log('skip (already): #codeChip css');
  }
})();

console.log('MARQUEE PATCH OK');
