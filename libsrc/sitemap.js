'use strict';
/* CS-4: dynamic sitemap.xml + robots.txt. Lists only REAL, indexable URLs pulled
   live from the DB — static pages, categories, products, content hubs (that have
   posts) and published articles. Base URL from SITE_DOMAIN, with request-host
   fallback so it works behind any proxy. No build step, always current. */
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();

  const TYPE_PREFIX = { article: 'blog', news: 'news', guide: 'guides', tutorial: 'tutorials', review: 'reviews', comparison: 'comparisons', buying_guide: 'buying-guides', troubleshooting: 'troubleshooting', faq: 'knowledge', knowledge: 'knowledge' };

  function base(req) {
    const d = (process.env.SITE_DOMAIN || '').replace(/\/+$/, '');
    if (d) return /^https?:/i.test(d) ? d : ('https://' + d);
    const proto = (req.get('x-forwarded-proto') || req.protocol || 'https').split(',')[0].trim();
    return proto + '://' + req.get('host');
  }
  function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;'); }
  function iso(d) { try { return new Date(d).toISOString().slice(0, 10); } catch (e) { return ''; } }

  router.get('/sitemap.xml', async function (req, res) {
    try {
      const b = base(req);
      const urls = [];
      function add(loc, lastmod, changefreq, priority) { urls.push({ loc: b + loc, lastmod: lastmod || '', changefreq: changefreq || '', priority: priority || '' }); }

      // 1) static marketing pages
      add('/', '', 'daily', '1.0');
      add('/about', '', 'monthly', '0.5');
      add('/resellers', '', 'monthly', '0.6');
      add('/faq', '', 'monthly', '0.5');

      // 2) categories (live, active)
      const cats = (await pool.query('SELECT slug FROM categories WHERE active ORDER BY slug')).rows;
      cats.forEach(function (c) { add('/category/' + c.slug, '', 'weekly', '0.7'); });

      // 3) products (live, active, visible)
      const prods = (await pool.query('SELECT slug FROM products WHERE active AND NOT hidden ORDER BY slug')).rows;
      prods.forEach(function (p) { add('/product/' + p.slug, '', 'weekly', '0.8'); });

      // 4) content hubs — /blog always, typed hubs only when they hold posts
      const LIVE = "(status='published' OR (status='scheduled' AND scheduled_at IS NOT NULL AND scheduled_at<=now()))";
      const hubs = (await pool.query("SELECT type, max(COALESCE(updated_at,published_at,created_at)) mx FROM cs_posts WHERE " + LIVE + " GROUP BY type")).rows;
      add('/blog', '', 'weekly', '0.6');
      const seen = { blog: 1 };
      hubs.forEach(function (h) { const pre = TYPE_PREFIX[h.type] || 'blog'; if (!seen[pre]) { seen[pre] = 1; add('/' + pre, iso(h.mx), 'weekly', '0.6'); } });

      // 5) published articles, per-type canonical URL, newest first
      const posts = (await pool.query("SELECT type, slug, COALESCE(updated_at,published_at,created_at) lm FROM cs_posts WHERE " + LIVE + " ORDER BY lm DESC")).rows;
      posts.forEach(function (p) { const pre = TYPE_PREFIX[p.type] || 'blog'; add('/' + pre + '/' + p.slug, iso(p.lm), 'monthly', '0.7'); });

      const xml = '<?xml version="1.0" encoding="UTF-8"?>\n' +
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
        urls.map(function (u) {
          return '  <url><loc>' + esc(u.loc) + '</loc>' +
            (u.lastmod ? ('<lastmod>' + u.lastmod + '</lastmod>') : '') +
            (u.changefreq ? ('<changefreq>' + u.changefreq + '</changefreq>') : '') +
            (u.priority ? ('<priority>' + u.priority + '</priority>') : '') + '</url>';
        }).join('\n') +
        '\n</urlset>\n';
      res.set('Cache-Control', 'public, max-age=3600').type('application/xml').send(xml);
    } catch (e) { res.status(500).type('text/plain').send('sitemap error: ' + e.message); }
  });

  router.get('/robots.txt', function (req, res) {
    const b = base(req);
    const body = [
      'User-agent: *',
      'Allow: /',
      'Disallow: /admin',
      'Disallow: /checkout',
      'Disallow: /account',
      '',
      'Sitemap: ' + b + '/sitemap.xml',
      ''
    ].join('\n');
    res.set('Cache-Control', 'public, max-age=86400').type('text/plain').send(body);
  });

  return router;
};
