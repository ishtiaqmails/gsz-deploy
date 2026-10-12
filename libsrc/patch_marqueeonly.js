'use strict';
/* Top marquee = fully announcement-driven, with copyable coupon chips.
   - Only posted GENERAL announcements show (no hardcoded fallback / stored-setting lines).
   - Each announcement's coupon renders as a styled 🎟 chip; click/tap copies it.
   - The bar hides when there are no announcements (unless a promo code chip is present).
   Edits public/js/app.js (buildMarquee) + public/css/app.css (.mq-code + hover-pause).
   buildMarquee is always replaced (re-appliable); CSS add is guarded. */
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
"  var mqIcons=['<path d=\"M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z\"/>','<path d=\"M13 2 4 14h6l-1 8 9-12h-6l1-8Z\"/>','<path d=\"m12 3 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 18l-5.2 2.9 1-5.8L3.5 9l5.9-.9Z\"/>','<rect x=\"3\" y=\"5\" width=\"18\" height=\"12\" rx=\"2\"/><path d=\"M8 21h8M12 17v4\"/>','<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 7v5l3 2\"/>','<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"m8 12 3 3 5-6\"/>'];\n" +
"  function esc(x){var d=document.createElement('div');d.textContent=(x==null?'':String(x));return d.innerHTML;}\n" +
"  function hideBar(){ el.innerHTML=''; if(offer && !document.getElementById('codeChip')) offer.style.display='none'; }\n" +
"  if(!el.__mqWired){ el.__mqWired=1; el.addEventListener('click',function(e){ var c=(e.target&&e.target.closest)?e.target.closest('.mq-code'):null; if(!c)return; e.preventDefault(); var code=c.getAttribute('data-code')||''; if(!code)return; try{navigator.clipboard.writeText(code);}catch(err){} c.textContent='Copied \\u2713'; setTimeout(function(){ c.textContent='\\uD83C\\uDF9F '+code; },1300); }); }\n" +
"  fetch('/api/announcements',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():null;}).then(function(d){\n" +
"    var ann=((d&&d.items)||[]).filter(function(a){return !a.product;});\n" +
"    if(!ann.length){ hideBar(); return; }\n" +
"    if(offer) offer.style.display='';\n" +
"    var row=ann.map(function(a,i){ var t=esc(String(a.title||'').trim()); var chip=a.coupon?('<span class=\"mq-code\" data-code=\"'+esc(a.coupon)+'\">\\uD83C\\uDF9F '+esc(a.coupon)+'</span>'):''; return '<li><svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\">'+mqIcons[i%mqIcons.length]+'</svg>'+t+chip+'</li>'; }).join('');\n" +
"    el.innerHTML=row+row;\n" +
"  }).catch(function(){ hideBar(); });\n" +
"}";

  s = s.slice(0, a) + NEWFN + s.slice(b);
  fs.writeFileSync(file, s);
  console.log('ANNOUNCEMENT-ONLY MARQUEE (app.js) OK');
})();

/* ---- app.css: coupon chip styling + pause animation on hover ---- */
(function () {
  const file = path.join(ROOT, 'public/css/app.css');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('.mq-code{') >= 0) { console.log('skip (already): .mq-code css'); return; }
  const ANCHOR = '.marquee li svg{color:var(--c)}';
  const i = s.indexOf(ANCHOR);
  if (i < 0) throw new Error('ANCHOR MISS: .marquee li svg');
  const ADD = ANCHOR +
    '\n.mq-code{display:inline-flex;align-items:center;gap:4px;margin-left:8px;padding:2px 10px;border-radius:999px;background:rgba(255,255,255,.22);border:1px solid rgba(255,255,255,.3);color:#fff;font-weight:800;letter-spacing:.3px;cursor:pointer;white-space:nowrap}' +
    '\n.marquee ul:hover{animation-play-state:paused}';
  s = s.slice(0, i) + ADD + s.slice(i + ANCHOR.length);
  fs.writeFileSync(file, s);
  console.log('MQ-CODE CSS OK');
})();

console.log('MARQUEE PATCH OK');
