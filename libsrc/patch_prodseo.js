'use strict';
/* Per-product SEO: the shared head already renders metaDescription / canonicalUrl / ogTags / jsonLd
   when the route provides them (the cs-seo slot). This threads real product data into those vars
   from routes/products.js — meta description, Open Graph + Twitter cards, canonical, and a JSON-LD
   Product with real plan prices. No aggregateRating (no genuine per-product reviews → honest + spec-safe).
   Idempotent in-place patch. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodseo.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/products.js');
let s = fs.readFileSync(file, 'utf8');
let changed = false;

const RENDER = "      res.render('product', {";
if (s.indexOf('/* prodseo */') < 0 && s.indexOf(RENDER) >= 0) {
  const BLOCK = [
    "      /* prodseo */",
    "      const _esc = (v) => String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;');",
    "      const _base = (req.headers['x-forwarded-proto'] || req.protocol || 'https') + '://' + req.get('host');",
    "      const _canonical = _base + '/product/' + prow.slug;",
    "      const _img = _base + '/static/img/' + (prow.image || logoFile);",
    "      let _dsc = (prow.short_desc || prow.long_desc || (prow.name + ' — delivered fast on ' + siteName)).replace(/\\s+/g, ' ').trim();",
    "      if (_dsc.length > 160) _dsc = _dsc.slice(0, 157).replace(/\\s+\\S*$/, '') + '\\u2026';",
    "      const _prices = plans.map(p => Number(p.price) || 0).filter(n => n > 0);",
    "      const _low = _prices.length ? Math.min.apply(null, _prices) : 0;",
    "      const _high = _prices.length ? Math.max.apply(null, _prices) : 0;",
    "      const _inStock = plans.length ? plans.some(p => p.in_stock !== false) : true;",
    "      const _avail = _inStock ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock';",
    "      const _catName = (cats.filter(c => c.slug === prow.cat_slug)[0] || {}).name || null;",
    "      const metaDescription = _dsc;",
    "      const canonicalUrl = _canonical;",
    "      const ogTags = '<meta property=\"og:type\" content=\"product\">' +",
    "        '<meta property=\"og:site_name\" content=\"' + _esc(siteName) + '\">' +",
    "        '<meta property=\"og:title\" content=\"' + _esc(prow.name) + '\">' +",
    "        '<meta property=\"og:description\" content=\"' + _esc(_dsc) + '\">' +",
    "        '<meta property=\"og:url\" content=\"' + _esc(_canonical) + '\">' +",
    "        '<meta property=\"og:image\" content=\"' + _esc(_img) + '\">' +",
    "        '<meta name=\"twitter:card\" content=\"summary_large_image\">' +",
    "        '<meta name=\"twitter:title\" content=\"' + _esc(prow.name) + '\">' +",
    "        '<meta name=\"twitter:description\" content=\"' + _esc(_dsc) + '\">' +",
    "        '<meta name=\"twitter:image\" content=\"' + _esc(_img) + '\">' +",
    "        (_low ? ('<meta property=\"product:price:amount\" content=\"' + _low + '\"><meta property=\"product:price:currency\" content=\"PKR\">') : '');",
    "      const _ld = { '@context': 'https://schema.org/', '@type': 'Product', name: prow.name, image: [_img], description: _dsc, brand: { '@type': 'Brand', name: siteName }, sku: prow.slug };",
    "      if (_catName) _ld.category = _catName;",
    "      if (_prices.length) _ld.offers = (_low === _high)",
    "        ? { '@type': 'Offer', priceCurrency: 'PKR', price: _low, availability: _avail, url: _canonical }",
    "        : { '@type': 'AggregateOffer', priceCurrency: 'PKR', lowPrice: _low, highPrice: _high, offerCount: _prices.length, availability: _avail, url: _canonical };",
    "      const jsonLd = JSON.stringify(_ld).replace(/</g, '\\\\u003c');",
    ""
  ].join("\n");
  s = s.replace(RENDER, BLOCK + RENDER);
  changed = true; console.log('prodseo A: SEO block injected');
} else { console.log('prodseo A: present or anchor missing (skip)'); }

const CTX = "p: prow, plans, faqs, downloads, similar, accent, rating, orders, payNames, needMac";
const CTX2 = CTX + ", metaDescription, canonicalUrl, ogTags, jsonLd";
if (s.indexOf(", metaDescription, canonicalUrl, ogTags, jsonLd") < 0 && s.indexOf(CTX) >= 0) {
  s = s.replace(CTX, CTX2); changed = true; console.log('prodseo B: render vars added');
} else { console.log('prodseo B: present or anchor missing (skip)'); }

if (changed) fs.writeFileSync(file, s);
console.log('PRODSEO OK');
