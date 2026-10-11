'use strict';
/* Product page: show the SELECTED PLAN's product_note (set per plan on the product page),
   mirroring the availability-note/warranty pattern. Updates as the customer switches plans.
   - routes/products.js: plan objects carry product_note
   - views/product.ejs: per-pill data-note, a #planNote box, update() refreshes it
   Idempotent in-place patches. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodnote.js <ROOT>'); process.exit(1); }

/* ---- routes/products.js ---- */
(function(){
  const file = path.join(ROOT, 'routes/products.js');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;
  if (s.indexOf('avail_note, product_note,') >= 0) { console.log('products.js SELECT: present (skip)'); }
  else if (s.indexOf('warranty, avail_note, ') >= 0) { s = s.split('warranty, avail_note, ').join('warranty, avail_note, product_note, '); ch = true; console.log('products.js SELECT: +product_note'); }
  else console.log('products.js SELECT: anchor missing (skip)');
  const MAP = "avail_note: r.avail_note || '', warranty: _warr,";
  const MAP2 = "avail_note: r.avail_note || '', product_note: r.product_note || '', warranty: _warr,";
  if (s.indexOf("product_note: r.product_note") >= 0) { console.log('products.js MAP: present (skip)'); }
  else if (s.indexOf(MAP) >= 0) { s = s.replace(MAP, MAP2); ch = true; console.log('products.js MAP: +product_note'); }
  else console.log('products.js MAP: anchor missing (skip)');
  if (ch) fs.writeFileSync(file, s);
})();

/* ---- views/product.ejs ---- */
(function(){
  const file = path.join(ROOT, 'views/product.ejs');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;

  const CSSA = ".warr-note b{color:#8ff0c4}";
  const CSSB = CSSA + "\n  .note-box{display:flex;align-items:flex-start;gap:9px;margin:4px 0 16px;padding:12px 14px;border-radius:12px;background:rgba(41,211,255,.08);border:1px solid rgba(41,211,255,.3);color:#bfe9ff;font-size:13.5px;line-height:1.45}\n  .note-box svg{flex:none;margin-top:1px;width:18px;height:18px}\n  .note-box b{color:#9fe0ff}";
  if (s.indexOf(".note-box{") >= 0) { console.log('product.ejs CSS: present (skip)'); }
  else if (s.indexOf(CSSA) >= 0) { s = s.replace(CSSA, CSSB); ch = true; console.log('product.ejs CSS: note-box'); }
  else console.log('product.ejs CSS: anchor missing (skip)');

  const PILL = " data-warr=\"<%= pl.warranty||'' %>\"";
  const PILL2 = " data-warr=\"<%= pl.warranty||'' %>\" data-note=\"<%= pl.product_note||'' %>\"";
  if (s.indexOf("data-note=") >= 0) { console.log('product.ejs PILL: present (skip)'); }
  else if (s.indexOf(PILL) >= 0) { s = s.replace(PILL, PILL2); ch = true; console.log('product.ejs PILL: +data-note'); }
  else console.log('product.ejs PILL: anchor missing (skip)');

  const BLKA = "<span><b>Warranty:</b> <span id=\"planWarrText\"></span></span>\n      </div>";
  const BLKB = BLKA + "\n      <div class=\"note-box\" id=\"planNote\" style=\"display:none\">\n        <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M12 16v-4M12 8h.01\"/></svg>\n        <span><b>Note:</b> <span id=\"planNoteText\"></span></span>\n      </div>";
  if (s.indexOf('id="planNote"') >= 0) { console.log('product.ejs BLOCK: present (skip)'); }
  else if (s.indexOf(BLKA) >= 0) { s = s.replace(BLKA, BLKB); ch = true; console.log('product.ejs BLOCK: +planNote box'); }
  else console.log('product.ejs BLOCK: anchor missing (skip)');

  const JSA = "if(_wb){var _w=sel?(sel.getAttribute('data-warr')||''):'';if(_w){_wt.textContent=_w;_wb.style.display='';}else{_wb.style.display='none';}}\n";
  const JSB = JSA + "    var _nb=document.getElementById('planNote'),_nt=document.getElementById('planNoteText');\n    if(_nb){var _n=sel?(sel.getAttribute('data-note')||''):'';if(_n){_nt.textContent=_n;_nb.style.display='';}else{_nb.style.display='none';}}\n";
  if (s.indexOf("getElementById('planNoteText')") >= 0) { console.log('product.ejs JS: present (skip)'); }
  else if (s.indexOf(JSA) >= 0) { s = s.replace(JSA, JSB); ch = true; console.log('product.ejs JS: +planNote refresh'); }
  else console.log('product.ejs JS: anchor missing (skip)');

  if (ch) fs.writeFileSync(file, s);
})();

console.log('PRODNOTE OK');
