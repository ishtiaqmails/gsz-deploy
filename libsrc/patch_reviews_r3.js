'use strict';
/* Reviews R3 — admin product-assign + verified; remove Title field from the product form;
   drop the "checked before it appears" wording. Single-line anchors, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_reviews_r3.js <ROOT>'); process.exit(1); }
const AC = path.join(ROOT, 'routes/adminCatalog.js');
const PV = path.join(ROOT, 'views/product.ejs');

function sub(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) { console.log('MISS (left as-is): ' + name); return; }
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

/* --- adminCatalog.js --- */
sub(AC, 'ac:select', 'product_id,verified,created_at,customer_id',
  "const rows = (await pool.query('SELECT id,author,location,stars,body,approved FROM reviews ORDER BY id DESC')).rows;",
  "const rows = (await pool.query('SELECT id,author,location,stars,body,approved,product_id,verified,created_at,customer_id,title FROM reviews ORDER BY id DESC')).rows;\n    const products = (await pool.query('SELECT id,name FROM products WHERE active ORDER BY name')).rows;");
sub(AC, 'ac:render', 'rows, products, flash',
  "res.render('admin/reviews', { rows, flash: req.query.ok || null, active: 'reviews', title: 'Reviews' });",
  "res.render('admin/reviews', { rows, products, flash: req.query.ok || null, active: 'reviews', title: 'Reviews' });");
sub(AC, 'ac:save-vars', 'const _pid=parseInt(b.product_id',
  "const approved=b.approved?true:false; const id=parseInt(b.id,10)||0;",
  "const approved=b.approved?true:false; const id=parseInt(b.id,10)||0; const _pid=parseInt(b.product_id,10)||null; const _ver=b.verified?true:false;");
sub(AC, 'ac:save-update', 'product_id=$6,verified=$7',
  "if(id) await pool.query('UPDATE reviews SET author=$1,location=$2,stars=$3,body=$4,approved=$5 WHERE id=$6',[author,location,stars,bodyText,approved,id]);",
  "if(id) await pool.query('UPDATE reviews SET author=$1,location=$2,stars=$3,body=$4,approved=$5,product_id=$6,verified=$7 WHERE id=$8',[author,location,stars,bodyText,approved,_pid,_ver,id]);");
sub(AC, 'ac:save-insert', 'INSERT INTO reviews(author,location,stars,body,approved,product_id,verified)',
  "else await pool.query('INSERT INTO reviews(author,location,stars,body,approved) VALUES($1,$2,$3,$4,$5)',[author,location,stars,bodyText,approved]);",
  "else await pool.query('INSERT INTO reviews(author,location,stars,body,approved,product_id,verified) VALUES($1,$2,$3,$4,$5,$6,$7)',[author,location,stars,bodyText,approved,_pid,_ver]);");

/* --- product.ejs --- */
sub(PV, 'pv:note', 'thanks for your feedback!',
  "Verified purchase &middot; your review is checked before it appears.",
  "Verified purchase &middot; thanks for your feedback!");
sub(PV, 'pv:thanks', 'Your review was submitted.</p>',
  "&#10004; Thanks! Your review was submitted and will show here once approved.",
  "&#10004; Thanks! Your review was submitted.");
sub(PV, 'pv:drop-title', 'rv-title-removed',
  "<label class=\"fld\">Title (optional)</label>\n              <input type=\"text\" name=\"title\" maxlength=\"120\" placeholder=\"Sum it up in a few words\">\n              ",
  "<!--rv-title-removed-->");

console.log('REVIEWS R3 PATCH OK');
