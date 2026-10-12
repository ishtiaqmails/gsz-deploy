'use strict';
/* Top marquee = fully announcement-driven. Only posted GENERAL announcements show;
   no hardcoded fallback phrases, no stored-setting lines. The top bar hides when
   there are no announcements (unless a promo code chip is present).
   public/js/app.js — replaces the whole buildMarquee() function. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_marqueeonly.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'public/js/app.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*annOnly*/') >= 0) { console.log('skip (already): announcement-only marquee'); process.exit(0); }

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
"  function hideBar(){ el.innerHTML=''; if(offer && !document.getElementById('codeChip')) offer.style.display='none'; }\n" +
"  // fully announcement-driven: only posted general announcements appear in the top bar\n" +
"  fetch('/api/announcements',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():null;}).then(function(d){\n" +
"    var ann=((d&&d.items)||[]).filter(function(a){return !a.product;}).map(function(a){ var t=String(a.title||'').trim(); if(a.coupon) t+=' · Code '+a.coupon; return t; }).filter(Boolean);\n" +
"    if(!ann.length){ hideBar(); return; }\n" +
"    if(offer) offer.style.display='';\n" +
"    var row=ann.map(function(t,i){return '<li><svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\">'+mqIcons[i%mqIcons.length]+'</svg>'+t+'</li>';}).join('');\n" +
"    el.innerHTML=row+row;\n" +
"  }).catch(function(){ hideBar(); });\n" +
"}";

s = s.slice(0, a) + NEWFN + s.slice(b);
fs.writeFileSync(file, s);
console.log('ANNOUNCEMENT-ONLY MARQUEE PATCH OK');
