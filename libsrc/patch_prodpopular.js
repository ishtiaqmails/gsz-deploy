'use strict';
/* Most-Popular plan flag — backend wiring (in-place, idempotent).
   - adminCatalog.js: load `popular` for the editor, and after the plan upsert set popular by label
     (one statement; the fragile INSERT/UPDATE SQL is left untouched).
   - views/product.ejs: make sure the pill gets the `pop` class when pl.popular (robust matcher;
     the savepct patch's ribbon already renders — this adds the glow border).
   The ALTER TABLE + the public product-route pass-through are handled in the step script / separate patch. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodpopular.js <ROOT>'); process.exit(1); }

/* ---- adminCatalog.js ---- */
(function(){
  const file = path.join(ROOT, 'routes/adminCatalog.js');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;

  // 1) editor SELECT: add `popular`
  const SEL = "SELECT id, label, price_pkr, old_pkr, avail_from, avail_until, warranty FROM product_plans WHERE product_id=$1 ORDER BY sort,id";
  const SEL2 = "SELECT id, label, price_pkr, old_pkr, avail_from, avail_until, warranty, popular FROM product_plans WHERE product_id=$1 ORDER BY sort,id";
  if (s.indexOf(", warranty, popular FROM product_plans WHERE product_id=$1 ORDER BY sort,id") < 0 && s.indexOf(SEL) >= 0) {
    s = s.replace(SEL, SEL2); ch = true; console.log('adminCatalog A: editor SELECT +popular');
  } else { console.log('adminCatalog A: present or anchor missing (skip)'); }

  // 2) after the plan delete block, set popular by label (idempotent guard)
  if (s.indexOf('prodpopular-set') < 0) {
    const ANCH = "else await c.query('DELETE FROM product_plans WHERE product_id=$1', [id]);";
    if (s.indexOf(ANCH) >= 0) {
      const INS = ANCH + "\n      /* prodpopular-set: mark the chosen plan popular, clear the rest */\n" +
        "      { const _pl=((b.popular_label||'')+'').trim(); await c.query('UPDATE product_plans SET popular = (label = $2 AND $2 <> \\'\\') WHERE product_id=$1', [id, _pl]); }";
      s = s.replace(ANCH, INS); ch = true; console.log('adminCatalog B: popular UPDATE injected');
    } else { console.log('adminCatalog B: delete anchor missing (skip)'); }
  } else { console.log('adminCatalog B: present (skip)'); }

  if (ch) fs.writeFileSync(file, s);
})();

/* ---- views/product.ejs : ensure pill gets `pop` class (robust) ---- */
(function(){
  const file = path.join(ROOT, 'views/product.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf("pl.popular?' pop'") >= 0) { console.log('product.ejs C: pop class present (skip)'); return; }
  const A = "<%= oos?' oos':'' %>\"";
  const B = "<%= oos?' oos':'' %><%= pl.popular?' pop':'' %>\"";
  if (s.indexOf(A) >= 0) { s = s.replace(A, B); fs.writeFileSync(file, s); console.log('product.ejs C: pop class added (robust)'); }
  else { console.log('product.ejs C: anchor missing (skip)'); }
})();

console.log('PRODPOPULAR OK');
