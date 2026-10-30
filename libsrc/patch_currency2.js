'use strict';
/* CURRENCY2_v1 — Stage 2: auto geo currency, USD-base conversion, owner buffer. DISPLAY layer.
   Verbatim single-line anchors per file; done-marker-first => idempotent; throws on a miss so
   the deploy step restores. Checkout (Stage 3) still uses the old region logic until wired next. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const GEO_BLOCK =
  "\n  app.set('trust proxy', 1);\n" +
  "  try { var _gszPricing = require('./lib/gsz_pricing'); } catch (e) { var _gszPricing = null; }\n" +
  "  var __gszBuf = { v: 0, at: 0 };\n" +
  "  app.use(async (req, res, next) => { /* geo + currency (Stage 2) */\n" +
  "    try {\n" +
  "      var cc = String(req.headers['cf-ipcountry'] || '').toUpperCase();\n" +
  "      if (!/^[A-Z]{2}$/.test(cc) || cc === 'XX' || cc === 'T1') cc = '';\n" +
  "      res.locals.geoCountry = cc;\n" +
  "      res.locals.geoCur = (cc === 'PK') ? 'PKR' : ((cc && _gszPricing) ? (_gszPricing.curFor(cc) || 'USD') : 'PKR');\n" +
  "      if (Date.now() - __gszBuf.at > 60000) { __gszBuf.at = Date.now(); try { const _b = await pool.query(\"SELECT value FROM wa_settings WHERE key='price_buffer_pct'\"); __gszBuf.v = _b.rows[0] ? (parseFloat(_b.rows[0].value) || 0) : 0; } catch (e) {} }\n" +
  "      res.locals.priceBuffer = __gszBuf.v;\n" +
  "      res.setHeader('Vary', 'CF-IPCountry');\n" +
  "    } catch (e) {}\n" +
  "    next();\n" +
  "  });";

const edits = [
  // server.js — geo middleware right after the customer-locals middleware
  { file: 'server.js',
    old: "app.use((req, res, next) => { res.locals.customer = (req.session && req.session.customer) || null; next(); });",
    neu: "app.use((req, res, next) => { res.locals.customer = (req.session && req.session.customer) || null; next(); });" + GEO_BLOCK,
    done: "geo + currency (Stage 2)" },

  // store_bottom.ejs — inject __GEO beside __DATA
  { file: 'views/partials/store_bottom.ejs',
    old: "<script>window.__DATA = <%- shellJson %>;</script>",
    neu: "<script>window.__DATA = <%- shellJson %>; window.__GEO = { country: <%- JSON.stringify(locals.geoCountry||'') %>, cur: <%- JSON.stringify(locals.geoCur||'PKR') %>, bufferPct: <%= Number(locals.priceBuffer||0) %> };</script>",
    done: "window.__GEO =" },

  // app.js — auto currency from __GEO (+ buffer, + chip update) replacing the localStorage default
  { file: 'public/js/app.js',
    old: "try{var sv=localStorage.getItem('gsz_currency');if(sv){var f0=CURRENCIES.filter(function(c){return c.code===sv;})[0];if(f0)CUR=f0;}}catch(e){}",
    neu: "var BUF=0, USDRATE=0.0036; try{ var G=(window.__GEO||{}); BUF=Math.max(0,Math.min(90,Number(G.bufferPct)||0)); var want=String(G.cur||'PKR'); var f0=CURRENCIES.filter(function(c){return c.code===want;})[0]; CUR=f0||CURRENCIES.filter(function(c){return c.code==='USD';})[0]||CURRENCIES[0]; }catch(e){} document.addEventListener('DOMContentLoaded',function(){ try{ var lab=document.getElementById('curLabel'); if(lab)lab.textContent=CUR.code; var fl=document.getElementById('curFlag'); if(fl)fl.src='https://flagcdn.com/24x18/'+CUR.cc+'.png'; }catch(e){} });",
    done: "BUF=Math.max(0,Math.min(90" },

  // app.js — USD-aware + buffered paint
  { file: 'public/js/app.js',
    old: "function paintPrices(root){$$('[data-pkr]',root).forEach(function(el){el.textContent=money(el.dataset.pkr);});}",
    neu: "function _conv(pkr,usd){pkr=Number(pkr)||0;usd=Number(usd)||0;if(CUR.code==='PKR')return 'Rs '+Math.round(pkr).toLocaleString('en-US');var local=(usd>0&&USDRATE>0)?(usd*(CUR.rate/USDRATE)):(pkr*CUR.rate);if(BUF>0)local=local*(1-BUF/100);local=local<10?(Math.floor(local*100)/100):Math.floor(local);var num=local<10?local.toFixed(2):local.toLocaleString('en-US');return (/[A-Za-z]$/.test(CUR.sym)?(CUR.sym+' '):CUR.sym)+num;}\nfunction paintPrices(root){$$('[data-pkr]',root).forEach(function(el){el.textContent=_conv(el.dataset.pkr,el.dataset.usd);});}",
    done: "function _conv(pkr,usd)" },

  // app.js — capture live USD rate for USD-base conversion
  { file: 'public/js/app.js',
    old: "function applyRates(rates){CURRENCIES.forEach(function(c){if(c.code!=='PKR'&&rates[c.code])c.rate=rates[c.code];});}",
    neu: "function applyRates(rates){CURRENCIES.forEach(function(c){if(c.code!=='PKR'&&rates[c.code])c.rate=rates[c.code];});try{var u=CURRENCIES.filter(function(c){return c.code==='USD';})[0];if(u&&u.rate)USDRATE=u.rate;}catch(e){}}",
    done: "if(u&&u.rate)USDRATE=u.rate;" },

  // storefront.js — carry a USD "from" price per product
  { file: 'lib/storefront.js',
    old: "(SELECT MIN(price_pkr) FROM product_plans WHERE product_id=p.id) AS from_price,",
    neu: "(SELECT MIN(price_pkr) FROM product_plans WHERE product_id=p.id) AS from_price, (SELECT MIN(price_usd) FROM product_plans WHERE product_id=p.id AND price_usd>0) AS from_usd,",
    done: "AS from_usd," },
  { file: 'lib/storefront.js',
    old: "from:Number(r.from_price||0), plans:r.plan_count||0,",
    neu: "from:Number(r.from_price||0), from_usd:Number(r.from_usd||0), plans:r.plan_count||0,",
    done: "from_usd:Number(r.from_usd||0)," },
  { file: 'lib/storefront.js',
    old: "image:p.image, from:p.from, plans:p.plans })",
    neu: "image:p.image, from:p.from, from_usd:p.from_usd, plans:p.plans })",
    done: "from_usd:p.from_usd, plans:p.plans" },

  // category + home card "from" price -> add data-usd
  { file: 'views/category.ejs',
    old: "<span class=\"pprice\" data-pkr=\"'+p.from+'\"></span>",
    neu: "<span class=\"pprice\" data-pkr=\"'+p.from+'\" data-usd=\"'+(p.from_usd||'')+'\"></span>",
    done: "data-usd=\"'+(p.from_usd||'')+'\"" },
  { file: 'views/home.ejs',
    old: "<span class=\"pprice\" data-pkr=\"'+p.from+'\"></span>",
    neu: "<span class=\"pprice\" data-pkr=\"'+p.from+'\" data-usd=\"'+(p.from_usd||'')+'\"></span>",
    done: "data-usd=\"'+(p.from_usd||'')+'\"" },

  // product page plan pill + similar "from" -> add data-usd
  { file: 'views/product.ejs',
    old: "<span class=\"ppill-now\" data-pkr=\"<%= pl.price %>\"></span>",
    neu: "<span class=\"ppill-now\" data-pkr=\"<%= pl.price %>\" data-usd=\"<%= pl.price_usd||'' %>\"></span>",
    done: "<span class=\"ppill-now\" data-pkr=\"<%= pl.price %>\" data-usd=" },
  { file: 'views/product.ejs',
    old: "<span class=\"pprice\" data-pkr=\"<%= s.from %>\"></span>",
    neu: "<span class=\"pprice\" data-pkr=\"<%= s.from %>\" data-usd=\"<%= s.from_usd||'' %>\"></span>",
    done: "data-usd=\"<%= s.from_usd||'' %>\"" },
];

const cache = {};
function load(f) { if (!(f in cache)) cache[f] = fs.readFileSync(path.join(ROOT, f), 'utf8'); return cache[f]; }
let applied = 0, skipped = 0;
for (const e of edits) {
  const s = load(e.file);
  if (s.indexOf(e.done) >= 0) { skipped++; }
  else if (s.indexOf(e.old) >= 0) {
    if (s.split(e.old).length - 1 !== 1) throw new Error('anchor not unique in ' + e.file + ': ' + e.old.slice(0, 40));
    cache[e.file] = s.replace(e.old, e.neu); applied++;
  } else throw new Error('ANCHOR MISSING in ' + e.file + ': ' + e.old.slice(0, 55));
}
for (const f in cache) fs.writeFileSync(path.join(ROOT, f), cache[f]);
console.log('CURRENCY2_v1 applied=' + applied + ' skipped=' + skipped);
