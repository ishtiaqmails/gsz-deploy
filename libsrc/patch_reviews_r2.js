'use strict';
/* Reviews R2+R4 — customer-submitted, verified-buyer, moderated reviews on the product page.
   routes/products.js:
     - body parser for the review POST
     - load approved per-product reviews (+ count/avg), detect verified buyer + already-reviewed
     - add aggregateRating + review[] to Product JSON-LD ONLY when real reviews exist
     - pass review vars to the view
     - POST /:slug/review (verified buyer only -> pending)
   views/product.ejs:
     - real reviews list + "Write a review" form (verified buyers) in the reviews tab
   Single-line anchors, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_reviews_r2.js <ROOT>'); process.exit(1); }
const PJ = path.join(ROOT, 'routes/products.js');
const PV = path.join(ROOT, 'views/product.ejs');

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

/* 1) body parser */
once(PJ, 'pj:body', 'const _rvBody =',
  'const router = express.Router();',
  "const router = express.Router();\n  const _rvBody = express.urlencoded({ extended: true, limit: '32kb' });");

/* 2) load reviews + verified-buyer + already-reviewed (after the orders count) */
const LOAD =
  "const orders = (await pool.query(\"SELECT count(*)::int n FROM orders WHERE product_id=$1 AND status='delivered'\", [prow.id])).rows[0].n;\n" +
  "      const reviews = (await pool.query(\"SELECT author, location, stars, body, title, verified, created_at FROM reviews WHERE product_id=$1 AND approved ORDER BY id DESC LIMIT 50\", [prow.id])).rows;\n" +
  "      const revCount = reviews.length;\n" +
  "      const revAvg = revCount ? Math.round((reviews.reduce(function(a,r){return a+(Number(r.stars)||0);},0)/revCount)*10)/10 : 0;\n" +
  "      const _cust = (req.session && req.session.customer) ? req.session.customer : null;\n" +
  "      let canReview = false, alreadyReviewed = false;\n" +
  "      if (_cust) {\n" +
  "        const _bought = (await pool.query(\"SELECT 1 FROM orders WHERE customer_id=$1 AND product_id=$2 AND lower(status) IN ('delivered','completed','done') LIMIT 1\", [_cust.id, prow.id])).rows[0];\n" +
  "        canReview = !!_bought;\n" +
  "        if (canReview) { const _did = (await pool.query('SELECT 1 FROM reviews WHERE product_id=$1 AND customer_id=$2 LIMIT 1', [prow.id, _cust.id])).rows[0]; alreadyReviewed = !!_did; }\n" +
  "      }\n" +
  "      const reviewMsg = String((req.query && req.query.rv) || '');";
once(PJ, 'pj:load', 'const revCount = reviews.length',
  "const orders = (await pool.query(\"SELECT count(*)::int n FROM orders WHERE product_id=$1 AND status='delivered'\", [prow.id])).rows[0].n;",
  LOAD);

/* 3) aggregateRating + review[] in Product JSON-LD (real reviews only) */
once(PJ, 'pj:aggrating', '_ld.aggregateRating =',
  "const _faqLd = (faqs && faqs.length) ? {",
  "if (revCount > 0) { _ld.aggregateRating = { '@type': 'AggregateRating', ratingValue: revAvg, reviewCount: revCount, bestRating: 5, worstRating: 1 }; _ld.review = reviews.slice(0, 5).map(function (r) { return { '@type': 'Review', reviewRating: { '@type': 'Rating', ratingValue: r.stars, bestRating: 5, worstRating: 1 }, author: { '@type': 'Person', name: r.author || 'Customer' }, reviewBody: r.body || '' }; }); }\n      const _faqLd = (faqs && faqs.length) ? {");

/* 4) pass review vars to the view */
once(PJ, 'pj:render', 'reviews, revCount, revAvg, canReview',
  "payNames, needMac, metaDescription, canonicalUrl, ogTags, jsonLd",
  "payNames, needMac, metaDescription, canonicalUrl, ogTags, jsonLd, reviews, revCount, revAvg, canReview, alreadyReviewed, reviewMsg");

/* 5) POST /:slug/review (verified buyer -> pending) */
const POST =
  "router.post('/:slug/review', _rvBody, async function (req, res) {\n" +
  "    try {\n" +
  "      const prow = (await pool.query('SELECT id, slug, name FROM products WHERE slug=$1 AND active AND NOT hidden', [req.params.slug])).rows[0];\n" +
  "      if (!prow) return res.redirect('/product/' + encodeURIComponent(req.params.slug));\n" +
  "      const base = '/product/' + prow.slug;\n" +
  "      const cust = (req.session && req.session.customer) ? req.session.customer : null;\n" +
  "      if (!cust) return res.redirect('/login?next=' + encodeURIComponent(base));\n" +
  "      const _bought = (await pool.query(\"SELECT 1 FROM orders WHERE customer_id=$1 AND product_id=$2 AND lower(status) IN ('delivered','completed','done') LIMIT 1\", [cust.id, prow.id])).rows[0];\n" +
  "      if (!_bought) return res.redirect(base + '?rv=buy#reviews');\n" +
  "      const _dup = (await pool.query('SELECT 1 FROM reviews WHERE product_id=$1 AND customer_id=$2 LIMIT 1', [prow.id, cust.id])).rows[0];\n" +
  "      if (_dup) return res.redirect(base + '?rv=dup#reviews');\n" +
  "      const stars = Math.min(5, Math.max(1, parseInt(req.body.stars, 10) || 5));\n" +
  "      const bodyText = String(req.body.body || '').trim().slice(0, 1500);\n" +
  "      const title = String(req.body.title || '').trim().slice(0, 120);\n" +
  "      if (!bodyText) return res.redirect(base + '?rv=empty#reviews');\n" +
  "      await pool.query(\"INSERT INTO reviews(author, location, stars, body, title, approved, product_id, customer_id, verified) VALUES($1,$2,$3,$4,$5,false,$6,$7,true)\", [cust.name || 'Customer', '', stars, bodyText, title, prow.id, cust.id]);\n" +
  "      return res.redirect(base + '?rv=thanks#reviews');\n" +
  "    } catch (e) { return res.redirect('/product/' + encodeURIComponent(req.params.slug)); }\n" +
  "  });\n\n  return router;";
once(PJ, 'pj:post', "router.post('/:slug/review'", "  return router;", POST);

/* 6) product.ejs — reviews list + form in the reviews tab (single-line anchor, CRLF-safe) */
const ANCHOR6 = "<a class=\"btn btn-ghost\" href=\"/#reviews\">See customer reviews →</a>";
const UI = ANCHOR6 + "\n" +
  "        <style>.rv-wrap{margin-top:18px}.rv-item{border-top:1px solid #eef1f8;padding:14px 0}.rv-h{display:flex;align-items:center;gap:10px;flex-wrap:wrap}.rv-auth{font-weight:700;color:#0f1836}.rv-vb{font-size:11.5px;font-weight:700;color:#0b7a42;background:#e7f8ee;border-radius:999px;padding:2px 9px}.rv-st{color:#f5a524;letter-spacing:1px}.rv-t{font-weight:700;margin:6px 0 2px;color:#0f1836}.rv-b{color:#4a5578;font-size:14.5px;line-height:1.6;margin:0}.rv-form{margin-top:18px;background:#f7f9fe;border:1px solid #eaf0ff;border-radius:14px;padding:16px 18px}.rv-form .fld{display:block;font-size:12.5px;font-weight:700;color:#737e9c;margin:10px 0 5px}.rv-form select,.rv-form input,.rv-form textarea{width:100%;box-sizing:border-box;border:1px solid #dfe5f2;border-radius:10px;padding:10px 12px;font:inherit}.rv-ft{font-weight:800;font-size:15px;color:#0f1836;margin:0 0 4px}.rv-ok{color:#0b7a42;font-weight:700;margin:12px 0 0}.rv-note{color:#8b93bb;font-size:12.5px;margin-top:8px}</style>\n" +
  "        <div class=\"rv-wrap\">\n" +
  "          <% if (typeof reviewMsg !== 'undefined' && reviewMsg) { %><% if (reviewMsg==='thanks') { %><p class=\"rv-ok\">&#10004; Thanks! Your review was submitted and will show here once approved.</p><% } else if (reviewMsg==='buy') { %><p class=\"rv-note\">Only verified buyers of this product can leave a review.</p><% } else if (reviewMsg==='dup') { %><p class=\"rv-note\">You&rsquo;ve already reviewed this product &mdash; thank you!</p><% } else if (reviewMsg==='empty') { %><p class=\"rv-note\">Please write your review before submitting.</p><% } %><% } %>\n" +
  "          <% if (typeof reviews !== 'undefined' && reviews && reviews.length) { %>\n" +
  "            <% reviews.forEach(function(rv){ %>\n" +
  "              <div class=\"rv-item\"><div class=\"rv-h\"><span class=\"rv-auth\"><%= rv.author || 'Customer' %></span><% if (rv.verified) { %><span class=\"rv-vb\">&#10003; Verified purchase</span><% } %><span class=\"rv-st\"><% for(var z=0;z<5;z++){ %><%= z < (Number(rv.stars)||0) ? '\\u2605' : '\\u2606' %><% } %></span></div><% if (rv.title) { %><div class=\"rv-t\"><%= rv.title %></div><% } %><% if (rv.body) { %><p class=\"rv-b\"><%= rv.body %></p><% } %></div>\n" +
  "            <% }); %>\n" +
  "          <% } %>\n" +
  "          <% if (typeof canReview !== 'undefined' && canReview && !alreadyReviewed) { %>\n" +
  "            <form class=\"rv-form\" method=\"post\" action=\"/product/<%= p.slug %>/review\">\n" +
  "              <div class=\"rv-ft\">Write a review</div>\n" +
  "              <label class=\"fld\">Your rating</label>\n" +
  "              <select name=\"stars\"><% for(var sx=5;sx>=1;sx--){ %><option value=\"<%= sx %>\"><%= sx %> star<%= sx>1?'s':'' %></option><% } %></select>\n" +
  "              <label class=\"fld\">Title (optional)</label>\n" +
  "              <input type=\"text\" name=\"title\" maxlength=\"120\" placeholder=\"Sum it up in a few words\">\n" +
  "              <label class=\"fld\">Your review</label>\n" +
  "              <textarea name=\"body\" rows=\"3\" maxlength=\"1500\" placeholder=\"How was the product and the service?\" required></textarea>\n" +
  "              <button class=\"btn btn-p\" type=\"submit\" style=\"margin-top:12px\">Submit review</button>\n" +
  "              <p class=\"rv-note\">Verified purchase &middot; your review is checked before it appears.</p>\n" +
  "            </form>\n" +
  "          <% } else if (typeof alreadyReviewed !== 'undefined' && alreadyReviewed) { %>\n" +
  "            <p class=\"rv-note\">&#10004; You&rsquo;ve reviewed this product &mdash; thank you!</p>\n" +
  "          <% } %>\n" +
  "        </div>";
once(PV, 'pv:reviews', 'rv-wrap', ANCHOR6, UI);

console.log('REVIEWS R2 PATCH OK');
