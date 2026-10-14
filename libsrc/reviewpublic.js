'use strict';
/* Public, shareable review page — for manual/WhatsApp customers (no account/order needed).
   GET /review (+ /review/:slug to preselect a product), POST /review.
   Submissions are moderated (approved=false) and marked verified=false. */
const express = require('express');
const storefront = require('../lib/storefront');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '32kb' });

  async function shell() {
    const cats = await storefront.loadCats(pool);
    const settings = await storefront.loadSettings(pool);
    const products = await storefront.loadProducts(pool);
    const waNumber = settings.wa_number || process.env.WA_NUMBER || '';
    const shellJson = storefront.shellJson(cats, products, settings, waNumber);
    return { siteName: settings.site_name || 'Galaxy Subz × Zayron', logoFile: settings.logo_file || 'logo.png', waNumber, cats, settings, shellJson };
  }

  async function page(req, res, preslug) {
    const s = await shell();
    const prods = (await pool.query('SELECT name, slug FROM products WHERE active AND NOT hidden ORDER BY name')).rows;
    res.render('review', Object.assign(s, {
      title: 'Leave a review · ' + s.siteName,
      metaDescription: 'Share your experience with ' + s.siteName + ' — rate the product and service you received.',
      canonicalUrl: 'https://galaxyzayron.store/review',
      robotsMeta: 'noindex,follow', ogTags: '', jsonLd: '',
      prods: prods, preslug: preslug || '', msg: String((req.query && req.query.rv) || '')
    }));
  }

  router.get('/review', async (req, res) => { try { await page(req, res, ''); } catch (e) { res.status(500).send('Review page error: ' + e.message); } });
  router.get('/review/:slug', async (req, res) => { try { await page(req, res, req.params.slug); } catch (e) { res.status(500).send('Review page error: ' + e.message); } });

  router.post('/review', body, async (req, res) => {
    try {
      const slug = String(req.body.product || '').trim();
      const prow = slug ? (await pool.query('SELECT id FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0] : null;
      const author = String(req.body.author || '').trim().slice(0, 80);
      const stars = Math.min(5, Math.max(1, parseInt(req.body.stars, 10) || 5));
      const title = String(req.body.title || '').trim().slice(0, 120);
      const bodyText = String(req.body.body || '').trim().slice(0, 1500);
      const loc = String(req.body.location || '').trim().slice(0, 60);
      const backSlug = slug ? ('/' + encodeURIComponent(slug)) : '';
      if (!author || !bodyText) return res.redirect('/review' + backSlug + '?rv=empty');
      await pool.query('INSERT INTO reviews(author, location, stars, body, title, approved, product_id, verified) VALUES($1,$2,$3,$4,$5,false,$6,false)',
        [author, loc, stars, bodyText, title, prow ? prow.id : null]);
      return res.redirect('/review?rv=thanks');
    } catch (e) { return res.redirect('/review?rv=err'); }
  });

  return router;
};
