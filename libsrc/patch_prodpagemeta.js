'use strict';
/* Product page: show the SELECTED PLAN's availability note + warranty (updates as the customer
   switches plans). Availability falls back to the product-level note for older products.
   - routes/products.js: plan objects carry avail_note (warranty already present as `warranty`)
   - views/product.ejs: per-pill data-avail/data-warr, a dynamic availability box + a warranty box,
     and update() refreshes both on plan change.
   Idempotent in-place patches. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodpagemeta.js <ROOT>'); process.exit(1); }

/* ---- routes/products.js ---- */
(function(){
  const file = path.join(ROOT, 'routes/products.js');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;
  const SEL = "warranty, nf_portal_product_id FROM product_plans";
  const SEL2 = "warranty, avail_note, nf_portal_product_id FROM product_plans";
  if (s.indexOf("avail_note, nf_portal_product_id FROM product_plans") < 0 && s.indexOf(SEL) >= 0) { s = s.replace(SEL, SEL2); ch = true; console.log('products.js A: planRows +avail_note'); }
  else { console.log('products.js A: present/anchor missing (skip)'); }
  const MAP = "stock_count: a.stock_count, warranty: _warr,";
  const MAP2 = "stock_count: a.stock_count, avail_note: r.avail_note || '', warranty: _warr,";
  if (s.indexOf("avail_note: r.avail_note") < 0 && s.indexOf(MAP) >= 0) { s = s.replace(MAP, MAP2); ch = true; console.log('products.js B: plan map +avail_note'); }
  else { console.log('products.js B: present/anchor missing (skip)'); }
  if (ch) fs.writeFileSync(file, s);
})();

/* ---- views/product.ejs ---- */
(function(){
  const file = path.join(ROOT, 'views/product.ejs');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;

  // CSS: warranty note style
  const CSSA = ".geo-note b{color:#ffd9a0}";
  const CSSB = CSSA + "\n  .warr-note{display:flex;align-items:flex-start;gap:9px;margin:4px 0 16px;padding:12px 14px;border-radius:12px;background:rgba(42,209,127,.1);border:1px solid rgba(42,209,127,.35);color:#2ad17f;font-size:13.5px;line-height:1.45}\n  .warr-note svg{flex:none;margin-top:1px;width:18px;height:18px}\n  .warr-note b{color:#8ff0c4}";
  if (s.indexOf(".warr-note{") < 0 && s.indexOf(CSSA) >= 0) { s = s.replace(CSSA, CSSB); ch = true; console.log('product.ejs A: warr-note css'); }
  else { console.log('product.ejs A: present/anchor missing (skip)'); }

  // pill data attributes
  const PILL = " data-oos=\"<%= oos?'1':'0' %>\">";
  const PILL2 = " data-avail=\"<%= pl.avail_note||'' %>\" data-warr=\"<%= pl.warranty||'' %>\" data-oos=\"<%= oos?'1':'0' %>\">";
  if (s.indexOf("data-avail=") < 0 && s.indexOf(PILL) >= 0) { s = s.replace(PILL, PILL2); ch = true; console.log('product.ejs B: pill data-avail/data-warr'); }
  else { console.log('product.ejs B: present/anchor missing (skip)'); }

  // availability block -> dynamic + warranty block
  const BLK = "      <% if (p.geo_note) { %>\n      <div class=\"geo-note\">\n        <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M10.3 3.9 2.4 18a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z\"/><path d=\"M12 9v4M12 17h.01\"/></svg>\n        <span><b>Availability note:</b> <%= p.geo_note %></span>\n      </div>\n      <% } %>";
  const BLK2 = "      <div class=\"geo-note\" id=\"planAvail\"<%= p.geo_note?'':' style=\"display:none\"' %>>\n        <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M10.3 3.9 2.4 18a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z\"/><path d=\"M12 9v4M12 17h.01\"/></svg>\n        <span><b>Availability note:</b> <span id=\"planAvailText\"><%= p.geo_note || '' %></span></span>\n      </div>\n      <div class=\"warr-note\" id=\"planWarr\" style=\"display:none\">\n        <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 2 4 5v6c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V5z\"/><path d=\"m9 12 2 2 4-4\"/></svg>\n        <span><b>Warranty:</b> <span id=\"planWarrText\"></span></span>\n      </div>";
  if (s.indexOf('id="planAvail"') < 0 && s.indexOf(BLK) >= 0) { s = s.replace(BLK, BLK2); ch = true; console.log('product.ejs C: dynamic availability + warranty block'); }
  else { console.log('product.ejs C: present/anchor missing (skip)'); }

  // update() JS: refresh availability + warranty on plan change
  const JS = "    syncPrice();\n    var h=waHref();";
  const JS2 = "    syncPrice();\n" +
    "    var _av=document.getElementById('planAvail'),_avt=document.getElementById('planAvailText');\n" +
    "    if(_av){var _a=sel?(sel.getAttribute('data-avail')||''):'';if(!_a)_a=<%- JSON.stringify(p.geo_note||'') %>;if(_a){_avt.textContent=_a;_av.style.display='';}else{_av.style.display='none';}}\n" +
    "    var _wb=document.getElementById('planWarr'),_wt=document.getElementById('planWarrText');\n" +
    "    if(_wb){var _w=sel?(sel.getAttribute('data-warr')||''):'';if(_w){_wt.textContent=_w;_wb.style.display='';}else{_wb.style.display='none';}}\n" +
    "    var h=waHref();";
  if (s.indexOf("getElementById('planWarrText')") < 0 && s.indexOf(JS) >= 0) { s = s.replace(JS, JS2); ch = true; console.log('product.ejs D: update() refreshes avail+warranty'); }
  else { console.log('product.ejs D: present/anchor missing (skip)'); }

  if (ch) fs.writeFileSync(file, s);
})();

console.log('PRODPAGEMETA OK');
