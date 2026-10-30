'use strict';
/* CURRENCY3_v1 — Stage 2.1: worldwide coverage.
   1) gsz_pricing.js CC_CUR -> complete ISO country->currency map (sanctioned/hyperinflation -> USD).
   2) app.js converter made currency-agnostic: converts ANY currency from the live feed and formats
      with Intl.NumberFormat (every ISO currency, correct symbol), USD fallback only when the FX feed
      lacks a rate. Idempotent (done-marker-first); throws on a miss so the deploy step restores. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const CC_BLOCK = `const CC_CUR = {
  AD:'EUR', AE:'AED', AF:'AFN', AG:'XCD', AI:'XCD', AL:'ALL', AM:'AMD', AO:'AOA', AR:'ARS', AS:'USD', AT:'EUR', AU:'AUD', AW:'AWG', AX:'EUR', AZ:'AZN',
  BA:'BAM', BB:'BBD', BD:'BDT', BE:'EUR', BF:'XOF', BG:'BGN', BH:'BHD', BI:'BIF', BJ:'XOF', BL:'EUR', BM:'BMD', BN:'BND', BO:'BOB', BQ:'USD', BR:'BRL', BS:'BSD', BT:'BTN', BV:'NOK', BW:'BWP', BY:'BYN', BZ:'BZD',
  CA:'CAD', CC:'AUD', CD:'CDF', CF:'XAF', CG:'XAF', CH:'CHF', CI:'XOF', CK:'NZD', CL:'CLP', CM:'XAF', CN:'CNY', CO:'COP', CR:'CRC', CU:'USD', CV:'CVE', CW:'ANG', CX:'AUD', CY:'EUR', CZ:'CZK',
  DE:'EUR', DJ:'DJF', DK:'DKK', DM:'XCD', DO:'DOP', DZ:'DZD',
  EC:'USD', EE:'EUR', EG:'EGP', EH:'MAD', ER:'ERN', ES:'EUR', ET:'ETB',
  FI:'EUR', FJ:'FJD', FK:'FKP', FM:'USD', FO:'DKK', FR:'EUR',
  GA:'XAF', GB:'GBP', GD:'XCD', GE:'GEL', GF:'EUR', GG:'GBP', GH:'GHS', GI:'GIP', GL:'DKK', GM:'GMD', GN:'GNF', GP:'EUR', GQ:'XAF', GR:'EUR', GT:'GTQ', GU:'USD', GW:'XOF', GY:'GYD',
  HK:'HKD', HN:'HNL', HR:'EUR', HT:'HTG', HU:'HUF',
  ID:'IDR', IE:'EUR', IL:'ILS', IM:'GBP', IN:'INR', IO:'USD', IQ:'IQD', IR:'USD', IS:'ISK', IT:'EUR',
  JE:'GBP', JM:'JMD', JO:'JOD', JP:'JPY',
  KE:'KES', KG:'KGS', KH:'USD', KI:'AUD', KM:'KMF', KN:'XCD', KP:'USD', KR:'KRW', KW:'KWD', KY:'KYD', KZ:'KZT',
  LA:'LAK', LB:'USD', LC:'XCD', LI:'CHF', LK:'LKR', LR:'LRD', LS:'LSL', LT:'EUR', LU:'EUR', LV:'EUR', LY:'LYD',
  MA:'MAD', MC:'EUR', MD:'MDL', ME:'EUR', MF:'EUR', MG:'MGA', MH:'USD', MK:'MKD', ML:'XOF', MM:'MMK', MN:'MNT', MO:'MOP', MP:'USD', MQ:'EUR', MR:'MRU', MS:'XCD', MT:'EUR', MU:'MUR', MV:'MVR', MW:'MWK', MX:'MXN', MY:'MYR', MZ:'MZN',
  NA:'NAD', NC:'XPF', NE:'XOF', NF:'AUD', NG:'NGN', NI:'NIO', NL:'EUR', NO:'NOK', NP:'NPR', NR:'AUD', NU:'NZD', NZ:'NZD',
  OM:'OMR',
  PA:'PAB', PE:'PEN', PF:'XPF', PG:'PGK', PH:'PHP', PK:'PKR', PL:'PLN', PM:'EUR', PN:'NZD', PR:'USD', PS:'ILS', PT:'EUR', PW:'USD', PY:'PYG',
  QA:'QAR',
  RE:'EUR', RO:'RON', RS:'RSD', RU:'RUB', RW:'RWF',
  SA:'SAR', SB:'SBD', SC:'SCR', SD:'USD', SE:'SEK', SG:'SGD', SH:'SHP', SI:'EUR', SJ:'NOK', SK:'EUR', SL:'SLE', SM:'EUR', SN:'XOF', SO:'SOS', SR:'SRD', SS:'USD', ST:'STN', SV:'USD', SX:'ANG', SY:'USD', SZ:'SZL',
  TC:'USD', TD:'XAF', TG:'XOF', TH:'THB', TJ:'TJS', TK:'NZD', TL:'USD', TM:'TMT', TN:'TND', TO:'TOP', TR:'TRY', TT:'TTD', TV:'AUD', TW:'TWD', TZ:'TZS',
  UA:'UAH', UG:'UGX', UM:'USD', US:'USD', UY:'UYU', UZ:'UZS',
  VA:'EUR', VC:'XCD', VE:'USD', VG:'USD', VI:'USD', VN:'VND', VU:'VUV',
  WF:'XPF', WS:'WST',
  YE:'YER', YT:'EUR',
  ZA:'ZAR', ZM:'ZMW', ZW:'USD'
};`;

const cache = {};
function load(f) { if (!(f in cache)) cache[f] = fs.readFileSync(path.join(ROOT, f), 'utf8'); return cache[f]; }
let applied = 0, skipped = 0;

// --- 1) gsz_pricing.js: replace CC_CUR block (regex, done-marker first) ---
{
  const f = 'lib/gsz_pricing.js';
  let s = load(f);
  if (s.indexOf("AD:'EUR'") >= 0) { skipped++; }
  else {
    const re = /const CC_CUR = \{[\s\S]*?\n\};/;
    if (!re.test(s)) throw new Error('CC_CUR block not found in ' + f);
    cache[f] = s.replace(re, CC_BLOCK); applied++;
  }
}

// --- 2) app.js: three single-line swaps (current = Stage-2 content) ---
const appEdits = [
  // geo-init: CUR from geoCur as plain object (no CURRENCIES membership needed); seed RATES; flag from country
  { old: "var BUF=0, USDRATE=0.0036; try{ var G=(window.__GEO||{}); BUF=Math.max(0,Math.min(90,Number(G.bufferPct)||0)); var want=String(G.cur||'PKR'); var f0=CURRENCIES.filter(function(c){return c.code===want;})[0]; CUR=f0||CURRENCIES.filter(function(c){return c.code==='USD';})[0]||CURRENCIES[0]; }catch(e){} document.addEventListener('DOMContentLoaded',function(){ try{ var lab=document.getElementById('curLabel'); if(lab)lab.textContent=CUR.code; var fl=document.getElementById('curFlag'); if(fl)fl.src='https://flagcdn.com/24x18/'+CUR.cc+'.png'; }catch(e){} });",
    neu: "var BUF=0, USDRATE=0.0036, RATES={}; try{CURRENCIES.forEach(function(c){RATES[c.code]=c.rate;});}catch(e){} try{ var G=(window.__GEO||{}); BUF=Math.max(0,Math.min(90,Number(G.bufferPct)||0)); var want=String(G.cur||'PKR').toUpperCase(); var f0=CURRENCIES.filter(function(c){return c.code===want;})[0]; CUR=f0||{code:want,sym:want,cc:String(G.country||'').toLowerCase()}; }catch(e){} document.addEventListener('DOMContentLoaded',function(){ try{ var lab=document.getElementById('curLabel'); if(lab)lab.textContent=CUR.code; var fl=document.getElementById('curFlag'); var fc=(window.__GEO&&window.__GEO.country)?String(window.__GEO.country).toLowerCase():(CUR.cc||''); if(fl&&fc)fl.src='https://flagcdn.com/24x18/'+fc+'.png'; }catch(e){} });",
    done: "USDRATE=0.0036, RATES={}" },
  // _conv: generic (any currency from live feed) + Intl.NumberFormat formatter
  { old: "function _conv(pkr,usd){pkr=Number(pkr)||0;usd=Number(usd)||0;if(CUR.code==='PKR')return 'Rs '+Math.round(pkr).toLocaleString('en-US');var local=(usd>0&&USDRATE>0)?(usd*(CUR.rate/USDRATE)):(pkr*CUR.rate);if(BUF>0)local=local*(1-BUF/100);local=local<10?(Math.floor(local*100)/100):Math.floor(local);var num=local<10?local.toFixed(2):local.toLocaleString('en-US');return (/[A-Za-z]$/.test(CUR.sym)?(CUR.sym+' '):CUR.sym)+num;}",
    neu: "function _fmt(code,v){try{return new Intl.NumberFormat('en-US',{style:'currency',currency:code,minimumFractionDigits:v<10?2:0,maximumFractionDigits:v<10?2:0}).format(v);}catch(e){var num=v<10?v.toFixed(2):Math.round(v).toLocaleString('en-US');return code+' '+num;}}\nfunction _conv(pkr,usd){pkr=Number(pkr)||0;usd=Number(usd)||0;if(CUR.code==='PKR')return 'Rs '+Math.round(pkr).toLocaleString('en-US');var ur=RATES['USD']||USDRATE||0.0036;var usdv=(usd>0)?usd:(pkr*ur);var code=CUR.code,rate=RATES[code],local;if(rate){local=usdv*(rate/ur);}else{code='USD';local=usdv;}if(BUF>0)local=local*(1-BUF/100);local=local<10?(Math.floor(local*100)/100):Math.floor(local);return _fmt(code,local);}",
    done: "function _fmt(code,v)" },
  // applyRates: also capture the FULL live rates table (any currency)
  { old: "function applyRates(rates){CURRENCIES.forEach(function(c){if(c.code!=='PKR'&&rates[c.code])c.rate=rates[c.code];});try{var u=CURRENCIES.filter(function(c){return c.code==='USD';})[0];if(u&&u.rate)USDRATE=u.rate;}catch(e){}}",
    neu: "function applyRates(rates){CURRENCIES.forEach(function(c){if(c.code!=='PKR'&&rates[c.code])c.rate=rates[c.code];});try{for(var k in rates){if(rates[k])RATES[k]=rates[k];}if(rates['USD'])USDRATE=rates['USD'];}catch(e){}}",
    done: "for(var k in rates){if(rates[k])RATES[k]=rates[k];}" },
];
{
  const f = 'public/js/app.js';
  let s = load(f);
  for (const e of appEdits) {
    if (s.indexOf(e.done) >= 0) { skipped++; }
    else if (s.indexOf(e.old) >= 0) {
      if (s.split(e.old).length - 1 !== 1) throw new Error('anchor not unique in ' + f + ': ' + e.old.slice(0, 40));
      s = s.replace(e.old, e.neu); applied++;
    } else throw new Error('ANCHOR MISSING in ' + f + ': ' + e.old.slice(0, 55));
  }
  cache[f] = s;
}

for (const f in cache) fs.writeFileSync(path.join(ROOT, f), cache[f]);
console.log('CURRENCY3_v1 applied=' + applied + ' skipped=' + skipped);
