'use strict';
/* #75 — feed GENERAL announcements into the top marquee (public/js/app.js).
   After the evergreen phrases render, prepend global announcements (target=All;
   identified by an empty `product` field) so posting a general announcement shows
   in the top strip. Product-aware ones are excluded here. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_marquee.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'public/js/app.js');
let s = fs.readFileSync(file, 'utf8');

const GUARD = '/*annMarquee*/';
if (s.indexOf(GUARD) >= 0) { console.log('skip (already): marquee announcements'); process.exit(0); }

const FIND = "  el.innerHTML=row+row;\n}";
const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: buildMarquee el.innerHTML');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: buildMarquee');

const ADD =
"  el.innerHTML=row+row;\n" +
"  /*annMarquee*/ try{ fetch('/api/announcements',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():null;}).then(function(d){\n" +
"    var ann=((d&&d.items)||[]).filter(function(a){return !a.product;}).map(function(a){ var t=String(a.title||'').trim(); if(a.coupon) t+=' \\u00b7 Code '+a.coupon; return t; }).filter(Boolean);\n" +
"    if(!ann.length) return; var all=ann.concat(items);\n" +
"    var r2=all.map(function(t,i){return '<li><svg class=\"ic ic-sm\" viewBox=\"0 0 24 24\">'+mqIcons[i%mqIcons.length]+'</svg>'+t+'</li>';}).join('');\n" +
"    el.innerHTML=r2+r2;\n" +
"  }).catch(function(){}); }catch(e){}\n" +
"}";
s = s.slice(0, i) + ADD + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('MARQUEE ANNOUNCEMENTS PATCH OK');
