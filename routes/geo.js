'use strict';
/* routes/geo.js — public Geo Page Engine route (SAFE FALL-THROUGH).
 *
 * MOUNT LAST, just before the 404 handler:
 *     const geoRouter = require('./routes/geo')(pool);
 *     app.use('/', geoRouter);          // <-- after every other app.use/get, before 404
 *
 * Why this cannot shadow or break an existing URL:
 *   - It only answers when the EXACT request path matches a geo_pages row whose
 *     status='PUBLISHED'. For anything else it calls next() -> your normal 404 /
 *     other handlers run unchanged.
 *   - Until a page is explicitly published, NO row is PUBLISHED, so the router is
 *     inert: every request falls through. Staging it changes nothing live.
 *   - It never registers a greedy pattern that matches first; mounted last, all
 *     real routes have already had their turn.
 *
 * On a hit it renders stored content_data, then RE-HYDRATES prices live through
 * gsz_pricing so figures are never stale, and sets X-Robots-Tag from the page's
 * indexing decision (defence-in-depth alongside the <meta robots> the template
 * emits via seo_meta).
 */
const path = require('path');

module.exports = function (pool) {
  const express = require('express');
  const router = express.Router();

  // lazy, defensive requires — a missing lib must never crash the app
  const lib = (name) => { try { return require(path.join(__dirname, '..', 'lib', name)); } catch (e) { try { return require(path.join(__dirname, '..', 'libsrc', name)); } catch (e2) { return null; } } };
  const seoMeta = lib('seo_meta');
  const pricing = lib('gsz_pricing');

  const SITE_URL = process.env.SITE_URL || 'https://galaxyzayron.store';
  const SITE_NAME = process.env.SITE_NAME || 'Galaxy Zayron';

  function normPath(p) {
    if (!p) return '/';
    p = p.split('?')[0].split('#')[0];
    if (p.length > 1) p = p.replace(/\/+$/, '');
    return p.toLowerCase();
  }

  // Only consider paths that look like a geo page: at least /{category}/{country}.
  // Cheap guard so the DB isn't hit for every stray 404.
  function looksGeo(p) {
    const seg = p.split('/').filter(Boolean);
    return seg.length >= 2 && seg.length <= 4 && seg.every(s => /^[a-z0-9-]+$/.test(s));
  }

  router.get(/.*/, async function (req, res, next) {
    try {
      const p = normPath(req.path);
      if (p === '/' || !looksGeo(p)) return next();

      const row = (await pool.query(
        "SELECT * FROM geo_pages WHERE lower(slug)=$1 AND status='PUBLISHED' LIMIT 1", [p])).rows[0];
      if (!row) return next();                       // <-- the safety: unknown path, hand back to the app

      const data = row.content_data || {};

      // Live price re-hydration (best-effort; display falls back to stored value).
      let products = Array.isArray(data.products) ? data.products.slice() : [];
      const cc = (data.locale && data.locale.countryCode) || null;
      if (pricing && cc && products.length) {
        for (const pr of products) {
          try {
            const base = { pkr: pr.price, usd: pr.priceUsd, price: pr.price };
            const q = await pricing.resolve(base, cc, {});
            if (q && q.display) { pr.priceDisplay = q.display; pr.priceCurrency = q.currency; pr.priceSymbol = q.symbol; }
          } catch (e) { /* keep stored */ }
        }
      }

      const indexing = (row.indexing_status === 'AUTO') ? 'INDEX' : row.indexing_status; // AUTO resolved at publish
      if (indexing === 'NOINDEX') res.set('X-Robots-Tag', 'noindex, follow');

      const ctx = {
        siteName: SITE_NAME, siteUrl: SITE_URL, path: p, lang: row.language || 'en',
        indexing,
        page: { seo_title: row.seo_title, seo_description: row.seo_description, canonical_url: row.canonical_url || (SITE_URL + p) },
        categoryName: (data.breadcrumbs && data.breadcrumbs[1] && data.breadcrumbs[1].name) || null,
        location: locFromData(data), country: null, region: null, city: null,
        intent: null,
        breadcrumbs: data.breadcrumbs || [],
        products: (data.products || []).map(mapMetaProduct),
        faq: data.faq || []
      };
      const headHtml = seoMeta ? seoMeta.renderHead(ctx) : '';

      return res.render('geo', {
        page: row, data, products, headHtml, ctx,
        h1: data.h1 || row.title || SITE_NAME,
        intro: data.intro || [],
        faq: data.faq || [],
        internalLinks: data.internalLinks || [],
        locale: data.locale || {},
        breadcrumbs: data.breadcrumbs || [],
        siteName: SITE_NAME, siteUrl: SITE_URL,
        // pass-throughs the existing shell may expect; the template guards for undefined
        assetVer: (req.app && req.app.locals && req.app.locals.assetVer) || function () { return ''; }
      }, function (err, html) {
        if (err) { console.error('[geo] render error for', p, err && err.message); return next(); } // never 500 the site
        res.send(html);
      });
    } catch (e) {
      console.error('[geo] route error:', e && e.message);
      return next();                                  // any failure -> behave as if no geo page
    }
  });

  function locFromData(data) {
    const bc = data.breadcrumbs || [];
    const last = bc.length ? bc[bc.length - 1] : null;
    const L = data.locale || {};
    return last ? { name: last.name, type: L.locationType || 'city', demonym: L.demonym, languages: L.languages, country_code: L.countryCode } : {};
  }
  function mapMetaProduct(p) {
    return { name: p.name, url: p.url, available: p.available !== false, price: p.price, priceUsd: p.priceUsd, currency: p.currency, description: p.description };
  }

  return router;
};
