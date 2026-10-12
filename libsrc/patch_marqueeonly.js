'use strict';
/* Top offer bar — consolidated, no duplicate coupon layers.
   - buildMarquee ONLY drives the scrolling marquee from GENERAL announcements
     (full message: <b>title</b> - body). It no longer creates its own coupon chip.
   - The coupon pill is the SERVER-rendered #codeChip (class code-chip) that the store
     template already emits from the admin's featured coupon ("SAVE 10% OWNER"). It copies
     its own data-code.
   - Fixes the legacy app.js init that hard-coded GALAXY10 onto #codeChip (that was the
     "Code GALAXY10 copied" bug) so it copies the chip's real data-code + a correct toast.
   - Strips the now-unused coupon-chip sub-CSS this patch previously added.
   Edits public/js/app.js (buildMarquee + the legacy #codeChip handler) and public/css/app.css.
   buildMarquee is always replaced (re-appliable); the other edits are guarded/idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_marqueeonly.js <ROOT>'); process.exit(1); }

/* ---- app.js (1): buildMarquee = scrolling announcements only ---- */
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
"  function settle(hasAnn){ if(!offer)return; offer.style.display=(hasAnn||document.getElementById('codeChip'))?'':'none'; }\n" +
"  fetch('/api/announcements',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():null;}).then(function(d){\n" +
"    var ann=((d&&d.items)||[]).filter(function(a){return !a.product;});\n" +
"    if(!ann.length){ el.innerHTML=''; settle(false); return; }\n" +
"    settle(true);\n" +
"    var row=ann.map(function(a,i){ var t=esc(String(a.title||'').trim()); var bd=esc(String(a.body||'').trim()); var msg=(t?('<b>'+t+'</b>'):'')+((t&&bd)?' \\u2014 ':'')+(bd||''); if(!msg)msg='New update'; return '<li><svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\">'+mqIcons[i%mqIcons.length]+'</svg>'+msg+'</li>'; }).join('');\n" +
"    el.innerHTML=row+row;\n" +
"  }).catch(function(){ el.innerHTML=''; settle(false); });\n" +
"}";

  s = s.slice(0, a) + NEWFN + s.slice(b);
  fs.writeFileSync(file, s);
  console.log('MARQUEE (announcements only) OK');
})();

/* ---- app.js (2): fix the legacy hard-coded GALAXY10 coupon handler ---- */
(function () {
  const file = path.join(ROOT, 'public/js/app.js');
  let s = fs.readFileSync(file, 'utf8');
  const FIND = "var cc=$('#codeChip'); if(cc)cc.onclick=function(){try{navigator.clipboard.writeText('GALAXY10');toast('Code GALAXY10 copied');}catch(e){toast('Code: GALAXY10');}};";
  const REPL = "var cc=$('#codeChip'); if(cc)cc.onclick=function(){var cd=(cc.getAttribute('data-code')||'').trim();if(!cd)return;try{navigator.clipboard.writeText(cd);toast('Coupon '+cd+' copied');}catch(e){toast('Coupon: '+cd);}};";
  if (s.indexOf(REPL) >= 0) { console.log('skip (already): coupon handler fixed'); return; }
  if (s.indexOf(FIND) < 0) throw new Error('ANCHOR MISS: legacy GALAXY10 handler');
  s = s.replace(FIND, REPL);
  fs.writeFileSync(file, s);
  console.log('COUPON HANDLER FIX OK (copies real data-code)');
})();

/* ---- app.css: strip the unused coupon-chip sub-CSS this patch once added ---- */
(function () {
  const file = path.join(ROOT, 'public/css/app.css');
  let s = fs.readFileSync(file, 'utf8');
  const DROP = [
    '\n.mq-code{display:inline-flex;align-items:center;gap:4px;margin-left:8px;padding:2px 10px;border-radius:999px;background:rgba(255,255,255,.22);border:1px solid rgba(255,255,255,.3);color:#fff;font-weight:800;letter-spacing:.3px;cursor:pointer;white-space:nowrap}',
    '\n.marquee ul:hover{animation-play-state:paused}',
    '\n#codeChip.ok{background:#e9fbef;color:#128a3e}',
    '\n#codeChip .cc-ic{font-size:13px;line-height:1}',
    '\n#codeChip .cc-t{font-size:12.5px;font-weight:800;letter-spacing:.2px}',
    '\n#codeChip .cc-code{font-size:11px;font-weight:700;opacity:.62;padding-left:7px;margin-left:1px;border-left:1px solid rgba(74,33,199,.22)}',
    '\n#codeChip .cc-lb{font-size:10.5px;font-weight:700;letter-spacing:.3px;opacity:.6;text-transform:uppercase}'
  ];
  let changed = false;
  DROP.forEach(function (d) { if (s.indexOf(d) >= 0) { s = s.replace(d, ''); changed = true; } });
  if (changed) { fs.writeFileSync(file, s); console.log('STRIPPED unused coupon-chip sub-CSS'); }
  else { console.log('skip (clean): no unused chip sub-CSS'); }
})();

console.log('MARQUEE PATCH OK');
