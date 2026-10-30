'use strict';
/* CURRENCY4_v1 — display default = USD for all non-PK visitors; their LOCAL currency stays
   available in the picker (injected from __GEO). Buffer no longer shaves the owner-set base
   prices (PKR, USD) — it only applies to converted LOCAL currencies. 2 app.js edits.
   Idempotent (done-marker-first); throws on a miss so the deploy step restores. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const F = 'public/js/app.js';

const edits = [
  // geo-init: default PK->PKR, everyone else->USD; inject visitor's local currency into the picker list
  { old: "var BUF=0, USDRATE=0.0036, RATES={}; try{CURRENCIES.forEach(function(c){RATES[c.code]=c.rate;});}catch(e){} try{ var G=(window.__GEO||{}); BUF=Math.max(0,Math.min(90,Number(G.bufferPct)||0)); var want=String(G.cur||'PKR').toUpperCase(); var f0=CURRENCIES.filter(function(c){return c.code===want;})[0]; CUR=f0||{code:want,sym:want,cc:String(G.country||'').toLowerCase()}; }catch(e){} document.addEventListener('DOMContentLoaded',function(){ try{ var lab=document.getElementById('curLabel'); if(lab)lab.textContent=CUR.code; var fl=document.getElementById('curFlag'); var fc=(window.__GEO&&window.__GEO.country)?String(window.__GEO.country).toLowerCase():(CUR.cc||''); if(fl&&fc)fl.src='https://flagcdn.com/24x18/'+fc+'.png'; }catch(e){} });",
    neu: "var BUF=0, USDRATE=0.0036, RATES={}; try{CURRENCIES.forEach(function(c){RATES[c.code]=c.rate;});}catch(e){} try{ var G=(window.__GEO||{}); BUF=Math.max(0,Math.min(90,Number(G.bufferPct)||0)); var ctry=String(G.country||'').toUpperCase(); var loc=String(G.cur||'').toUpperCase(); if(loc&&loc!=='PKR'&&loc!=='USD'&&!CURRENCIES.filter(function(c){return c.code===loc;})[0]){CURRENCIES.push({code:loc,sym:loc,cc:ctry.toLowerCase(),rate:(RATES[loc]||0)});} var want=(ctry==='PK')?'PKR':(ctry?'USD':(loc||'PKR')); var f0=CURRENCIES.filter(function(c){return c.code===want;})[0]; CUR=f0||{code:want,sym:(want==='USD'?'$':want),cc:(want==='USD'?'us':ctry.toLowerCase())}; }catch(e){} document.addEventListener('DOMContentLoaded',function(){ try{ var lab=document.getElementById('curLabel'); if(lab)lab.textContent=CUR.code; var fl=document.getElementById('curFlag'); if(fl&&CUR.cc)fl.src='https://flagcdn.com/24x18/'+CUR.cc+'.png'; }catch(e){} });",
    done: "var want=(ctry==='PK')?'PKR':(ctry?'USD':" },

  // _conv: buffer only shaves converted LOCAL currencies, never the owner-set USD/PKR base
  { old: "if(rate){local=usdv*(rate/ur);}else{code='USD';local=usdv;}if(BUF>0)local=local*(1-BUF/100);",
    neu: "if(rate){local=usdv*(rate/ur);}else{code='USD';local=usdv;}if(BUF>0&&code!=='USD')local=local*(1-BUF/100);",
    done: "if(BUF>0&&code!=='USD')local=local*(1-BUF/100);" },
];

let s = fs.readFileSync(path.join(ROOT, F), 'utf8');
let applied = 0, skipped = 0;
for (const e of edits) {
  if (s.indexOf(e.done) >= 0) { skipped++; continue; }
  const n = s.split(e.old).length - 1;
  if (n === 0) throw new Error('ANCHOR MISSING in ' + F + ': ' + e.old.slice(0, 55));
  if (n !== 1) throw new Error('anchor not unique: ' + e.old.slice(0, 40));
  s = s.split(e.old).join(e.neu); applied++;  // split/join: literal, immune to $ replacement patterns
}
fs.writeFileSync(path.join(ROOT, F), s);
console.log('CURRENCY4_v1 applied=' + applied + ' skipped=' + skipped);
