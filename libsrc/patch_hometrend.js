'use strict';
/* Home "Trending products" rail now driven by the ★ most_selling flag (not the old trending flag),
   with no fallback — so it shows only products you star, and hides when none are starred.
   Keeps the "Trending products" heading. Patches lib/storefront.js (expose most_selling) + views/home.ejs. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_hometrend.js <ROOT>'); process.exit(1); }

/* lib/storefront.js — expose most_selling on each product */
(function(){
  const file = path.join(ROOT, 'lib/storefront.js');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;
  const SEL = "p.short_desc AS descr, p.image, p.trending,";
  const SEL2 = "p.short_desc AS descr, p.image, p.trending, p.most_selling,";
  if (s.indexOf("p.most_selling,") < 0 && s.indexOf(SEL) >= 0) { s = s.replace(SEL, SEL2); ch = true; console.log('storefront: SELECT +most_selling'); }
  else { console.log('storefront: SELECT present/anchor missing (skip)'); }
  const MAP = "plans:r.plan_count||0, trending:!!r.trending }";
  const MAP2 = "plans:r.plan_count||0, trending:!!r.trending, most_selling:!!r.most_selling }";
  if (s.indexOf("most_selling:!!r.most_selling") < 0 && s.indexOf(MAP) >= 0) { s = s.replace(MAP, MAP2); ch = true; console.log('storefront: map +most_selling'); }
  else { console.log('storefront: map present/anchor missing (skip)'); }
  if (ch) fs.writeFileSync(file, s);
})();

/* views/home.ejs — rail from most_selling, no fallback */
(function(){
  const file = path.join(ROOT, 'views/home.ejs');
  let s = fs.readFileSync(file, 'utf8');
  const OLD = "var trending = products.filter(function(p){return p.trending;}); if(!trending.length) trending = products.slice(0,8);";
  const NEW = "var trending = products.filter(function(p){return p.most_selling;});";
  if (s.indexOf("return p.most_selling;") >= 0) { console.log('home.ejs: present (skip)'); }
  else if (s.indexOf(OLD) >= 0) { s = s.replace(OLD, NEW); fs.writeFileSync(file, s); console.log('home.ejs: rail -> most_selling (no fallback)'); }
  else { console.log('home.ejs: anchor missing (skip)'); }
})();

console.log('HOMETREND OK');
