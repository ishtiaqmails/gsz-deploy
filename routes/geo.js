'use strict';
/* routes/geo.js — public Geo Page Engine route (SAFE FALL-THROUGH).
 *
 * MOUNT LAST, right after the review router and before app.get('/'):
 *     const geoRouter = require('./routes/geo')(pool);
 *     app.use('/', geoRouter);
 *
 * Why it cannot shadow or break an existing URL:
 *   - Answers ONLY when req.path exactly matches a geo_pages row with
 *     status='PUBLISHED'. Everything else -> next() (your 404/other handlers run).
 *   - Until a page is published, NO row is PUBLISHED, so the router is inert.
 *   - Mounted last, every real route already had its turn.
 *   - Any render error or exception -> next() (never 500s the site).
 *
 * It reuses the SAME shell (partials/store_top + store_bottom) and the SAME
 * live products (storefront.loadProducts) as the category page, so prices paint
 * through the existing app.js and the page matches the site exactly.
 */
const path = require('path');

module.exports = function (pool) {
  const express = require('express');
  const router = express.Router();

  const lib = (name) => { try { return require(path.join(__dirname, '..', 'lib', name)); } catch (e) { return null; } };
  const storefront = lib('storefront');
  const seoMeta = lib('seo_meta');
  const geoSvc = (function () { try { return require(path.join(__dirname, '..', 'lib', 'geo'))(pool); } catch (e) { return null; } })();

  const SITE_URL = (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '');

  function normPath(p) {
    if (!p) return '/';
    p = p.split('?')[0].split('#')[0];
    if (p.length > 1) p = p.replace(/\/+$/, '');
    return p.toLowerCase();
  }
  // cheap guard so the DB isn't hit on every stray request
  function looksGeo(p) {
    const seg = p.split('/').filter(Boolean);
    return seg.length >= 2 && seg.length <= 4 && seg.every(s => /^[a-z0-9-]+$/.test(s));
  }

  router.get(/.*/, async function (req, res, next) {
    try {
      const p = normPath(req.path);
      if (p === '/' || !looksGeo(p)) return next();

      const page = (await pool.query(
        "SELECT * FROM geo_pages WHERE lower(slug)=$1 AND status='PUBLISHED' LIMIT 1", [p])).rows[0];
      if (!page) return next();                                    // the safety: unknown path -> back to the app

      const data = page.content_data || {};

      // ---- shell locals (same assembly as the category route) ----
      const [cats, settings, bannerMap] = await Promise.all([
        storefront.loadCats(pool).catch(() => []),
        storefront.loadSettings(pool).catch(() => ({})),
        storefront.loadBannerMap(pool).catch(() => ({}))
      ]);
      const siteName = settings.site_name || 'Galaxy Subz × Zayron';
      const logoFile = settings.logo_file || 'logo.png';
      const waNumber = settings.wa_number || process.env.WA_NUMBER || '';

      // ---- live products for this page's category, with geo rules applied ----
      let products = [];
      try {
        products = await storefront.loadProducts(pool, page.category_id || null);
        products = await applyGeoRules(products, page);
      } catch (e) { products = []; }
      const shellJson = storefront.shellJson(cats, products, settings, waNumber);

      // category row (for breadcrumbs/hero fallback)
      const cat = cats.find(c => c.id === page.category_id) ||
        { name: (data.breadcrumbs && data.breadcrumbs[1] && data.breadcrumbs[1].name) || siteName, slug: catSlugFromPath(p) };

      // ---- SEO head locals via the existing shell's own head slots ----
      const indexing = (page.indexing_status === 'AUTO') ? 'INDEX' : page.indexing_status;
      if (indexing === 'NOINDEX') res.set('X-Robots-Tag', 'noindex, follow');
      const ctx = {
        siteName, siteUrl: SITE_URL, path: p, lang: page.language || 'en', indexing,
        page: { seo_title: page.seo_title, seo_description: page.seo_description, canonical_url: page.canonical_url || (SITE_URL + p) },
        categoryName: cat.name,
        location: locFromData(data), country: null, region: null, city: null, intent: null,
        breadcrumbs: data.breadcrumbs || [],
        products: (data.products || []).map(mp => ({ name: mp.name, url: mp.url, available: mp.available !== false, price: mp.price, priceUsd: mp.priceUsd, currency: mp.currency, description: mp.description })),
        faq: data.faq || []
      };
      const seo = seoMeta ? seoMeta.storeTopLocals(ctx) : {};

      return res.render('geo', Object.assign({
        // shell
        siteName, logoFile, waNumber, cats, settings, shellJson, bannerMap, cat,
        // SEO head
        title: seo.title, metaDescription: seo.metaDescription, canonicalUrl: seo.canonicalUrl,
        robotsMeta: seo.robotsMeta, ogTags: seo.ogTags, jsonLd: seo.jsonLd,
        // geo content
        geoPage: page, h1: data.h1 || page.title || cat.name, intro: data.intro || [],
        faq: data.faq || [], internalLinks: data.internalLinks || [], products
      }), function (err, html) {
        if (err) { console.error('[geo] render error for', p, err && err.message); return next(); }
        res.send(html);
      });
    } catch (e) {
      console.error('[geo] route error:', e && e.message);
      return next();
    }
  });

  // Apply geo_product_rules for this page's location chain to the live product list.
  async function applyGeoRules(products, page) {
    if (!products || !products.length) return products || [];
    const locIds = [page.city_id, page.region_id, page.country_id].filter(Boolean);
    if (!locIds.length) return products;
    let rules = [];
    try {
      rules = (await pool.query(
        'SELECT product_id, location_id, availability, recommended, featured, special_notice FROM geo_product_rules WHERE location_id = ANY($1) AND enabled', [locIds])).rows;
    } catch (e) { return products; }
    if (!rules.length) return products;
    // depth: city(0) most specific
    const depth = {}; locIds.forEach((id, i) => { depth[id] = i; });
    const best = {};
    for (const r of rules) { const d = depth[r.location_id] == null ? 9 : depth[r.location_id]; const k = r.product_id; if (k == null) continue; if (!best[k] || d < best[k]._d) { r._d = d; best[k] = r; } }
    const out = [];
    for (const p of products) {
      const r = best[p.id];
      if (r && r.availability === 'unavailable') continue;
      if (r) { p._recommended = !!r.recommended; p._featured = !!r.featured; if (r.special_notice) p._notice = r.special_notice; }
      out.push(p);
    }
    out.sort((a, b) => (Number(b._featured) - Number(a._featured)) || (Number(b._recommended) - Number(a._recommended)));
    return out;
  }

  function catSlugFromPath(p) { const s = p.split('/').filter(Boolean); return s[0] || ''; }
  function locFromData(data) {
    const bc = data.breadcrumbs || [];
    const last = bc.length ? bc[bc.length - 1] : null;
    const L = data.locale || {};
    return last ? { name: last.name, type: L.locationType || 'city', demonym: L.demonym, languages: L.languages, country_code: L.countryCode } : {};
  }

  return router;
};
