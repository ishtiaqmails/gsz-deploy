'use strict';
/* Content Studio — public routes (dark theme). Listing hubs per type + article
   pages at /<prefix>/<slug>. Reuses storefront shell helpers so header/footer
   match the site exactly. Product/category cards pull LIVE data. */
const express = require('express');
const storefront = require('../lib/storefront');
const csblocks = require('../lib/csblocks');
const csrender = require('../lib/csrender');

module.exports = function (pool) {
  const router = express.Router();

  const TYPE_PREFIX = { article: 'blog', news: 'news', guide: 'guides', tutorial: 'tutorials', review: 'reviews', comparison: 'comparisons', buying_guide: 'buying-guides', troubleshooting: 'troubleshooting', faq: 'knowledge', knowledge: 'knowledge' };
  const PREFIX_TYPES = { blog: null, news: ['news'], guides: ['guide'], tutorials: ['tutorial'], reviews: ['review'], comparisons: ['comparison'], 'buying-guides': ['buying_guide'], troubleshooting: ['troubleshooting'], knowledge: ['faq', 'knowledge'] };
  const TYPE_LABEL = { article: 'Article', news: 'News', guide: 'Guide', tutorial: 'Tutorial', review: 'Review', comparison: 'Comparison', buying_guide: 'Buying Guide', troubleshooting: 'Troubleshooting', faq: 'Knowledge', knowledge: 'Knowledge' };
  const PREFIX_TITLE = { blog: 'Blog', news: 'News', guides: 'Guides', tutorials: 'Tutorials', reviews: 'Reviews', comparisons: 'Comparisons', 'buying-guides': 'Buying Guides', troubleshooting: 'Troubleshooting', knowledge: 'Knowledge Base' };

  function siteBase() { const d = (process.env.SITE_DOMAIN || '').replace(/\/+$/, ''); return d ? (/^https?:/i.test(d) ? d : ('https://' + d)) : ''; }
  function prefixOf(type) { return TYPE_PREFIX[type] || 'blog'; }
  function canonPath(p) { return '/' + prefixOf(p.type) + '/' + p.slug; }
  function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function dstr(d) { try { return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); } catch (e) { return ''; } }

  async function shell() {
    const cats = await storefront.loadCats(pool);
    const products = await storefront.loadProducts(pool);
    const settings = await storefront.loadSettings(pool);
    const waNumber = settings.wa_number || process.env.WA_NUMBER || '';
    return { cats, settings, waNumber, logoFile: settings.logo_file || 'logo.png', siteName: settings.site_name || 'Galaxy Subz × Zayron', shellJson: storefront.shellJson(cats, products, settings, waNumber) };
  }

  async function productsFor(refs) {
    const map = {}; if (!refs.length) return map;
    const slugs = refs.filter(function (r) { return !/^\d+$/.test(r); });
    const ids = refs.filter(function (r) { return /^\d+$/.test(r); }).map(Number);
    const rows = (await pool.query(
      `SELECT p.id, p.slug, p.name, p.short_desc, p.image, c.slug AS cat,
              (SELECT MIN(price_pkr) FROM product_plans WHERE product_id=p.id) AS from_price,
              (SELECT COUNT(*) FROM product_plans WHERE product_id=p.id)::int AS plan_count
       FROM products p JOIN categories c ON c.id=p.category_id
       WHERE p.active AND NOT p.hidden AND (p.slug = ANY($1) OR p.id = ANY($2))`,
      [slugs.length ? slugs : [''], ids.length ? ids : [-1]])).rows;
    const ACC = { entertainment: ['#7a2bff', '#c23bff'], iptv: ['#2a6cff', '#19c6ee'], vpns: ['#2a6cff', '#5b8bff'], tools: ['#7a2bff', '#2a6cff'], players: ['#19c6ee', '#2a6cff'] };
    rows.forEach(function (r) { const a = ACC[r.cat] || ['#2a6cff', '#19c6ee']; const o = { slug: r.slug, name: r.name, short_desc: r.short_desc || '', image: r.image || '', from: Number(r.from_price || 0), plans: r.plan_count || 0, g1: a[0], g2: a[1] }; map[r.slug] = o; map[String(r.id)] = o; });
    return map;
  }
  async function categoriesFor(refs) { const map = {}; if (!refs.length) return map; const rows = (await pool.query('SELECT slug,name,tag FROM categories WHERE active AND slug = ANY($1)', [refs])).rows; rows.forEach(function (r) { map[r.slug] = r; }); return map; }
  function collectRefs(blocks) { const prod = {}, cat = {}; (blocks || []).forEach(function (b) { if (b.type === 'productcard' && b.ref) prod[b.ref] = 1; if (b.type === 'productgrid' && b.refs) b.refs.forEach(function (r) { prod[r] = 1; }); if (b.type === 'categorycard' && b.ref) cat[b.ref] = 1; }); return { prod: Object.keys(prod), cat: Object.keys(cat) }; }

  function cardHtml(p, base) {
    const href = canonPath(p);
    const img = p.featured_image
      ? ('<img class="cl-img" loading="lazy" src="' + esc(p.featured_image) + '" alt="' + esc(p.title) + '">')
      : ('<div class="cl-img cl-ph"><span>' + esc(p.title.slice(0, 1).toUpperCase()) + '</span></div>');
    return '<a class="cl-card" href="' + esc(href) + '">' + img +
      '<div class="cl-body"><span class="cl-type">' + esc(TYPE_LABEL[p.type] || 'Article') + '</span>' +
      '<h3 class="cl-title">' + esc(p.title) + '</h3>' +
      (p.excerpt ? ('<p class="cl-ex">' + esc(p.excerpt) + '</p>') : '') +
      '<div class="cl-meta">' + (p.reading_time ? (esc(p.reading_time) + ' min read') : '') + (p.published_at ? (' · ' + dstr(p.published_at)) : '') + '</div></div></a>';
  }

  // ---- listing (hub + per type) ----
  function listHandler(prefix) {
    return async function (req, res) {
      try {
        const s = await shell();
        const types = PREFIX_TYPES[prefix];
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const per = 12; const off = (page - 1) * per;
        const where = ["status='published'"]; const params = [];
        if (types) { params.push(types); where.push('type = ANY($' + params.length + ')'); }
        const w = where.join(' AND ');
        const total = (await pool.query('SELECT count(*)::int n FROM cs_posts WHERE ' + w, params)).rows[0].n;
        params.push(per); params.push(off);
        const rows = (await pool.query('SELECT type,slug,title,excerpt,featured_image,reading_time,published_at FROM cs_posts WHERE ' + w + ' ORDER BY COALESCE(published_at,created_at) DESC LIMIT $' + (params.length - 1) + ' OFFSET $' + params.length, params)).rows;
        const cards = rows.map(function (p) { return cardHtml(p, siteBase()); }).join('');
        const base = siteBase();
        res.render('content_list', Object.assign({
          title: PREFIX_TITLE[prefix] + ' · ' + s.siteName,
          metaDescription: 'Guides, reviews, comparisons and news from ' + s.siteName + '.',
          canonicalUrl: base ? (base + '/' + prefix) : '',
          robotsMeta: 'index,follow', ogTags: '', jsonLd: '',
          hubTitle: PREFIX_TITLE[prefix], hubPrefix: prefix, cardsHtml: cards,
          page: page, pages: Math.max(1, Math.ceil(total / per)), total: total
        }, s));
      } catch (e) { res.status(500).send('Content list error: ' + e.message); }
    };
  }

  // ---- article ----
  function articleHandler(prefix) {
    return async function (req, res) {
      try {
        const slug = String(req.params.slug || '').toLowerCase();
        const post = (await pool.query('SELECT * FROM cs_posts WHERE slug=$1', [slug])).rows[0];
        if (!post || post.status !== 'published') {
          // redirect manager
          const rd = (await pool.query('SELECT to_path,code FROM cs_redirects WHERE from_path=$1', [req.path])).rows[0];
          if (rd) return res.redirect(rd.code || 301, rd.to_path);
          const s = await shell();
          return res.status(404).render('content_list', Object.assign({ title: 'Not found · ' + s.siteName, metaDescription: '', canonicalUrl: '', robotsMeta: 'noindex', ogTags: '', jsonLd: '', hubTitle: 'Not found', hubPrefix: 'blog', cardsHtml: '<p style="color:var(--muted)">That article could not be found.</p>', page: 1, pages: 1, total: 0 }, s));
        }
        // canonical prefix enforcement
        const canon = canonPath(post);
        if (req.path !== canon) return res.redirect(301, canon);

        const s = await shell();
        const base = siteBase();
        const author = post.author_id ? (await pool.query('SELECT name,slug,role,avatar FROM cs_authors WHERE id=$1', [post.author_id])).rows[0] : null;
        const authorName = (author && author.name) || s.siteName;
        const seo = (post.seo && typeof post.seo === 'object') ? post.seo : {};
        const blocks = Array.isArray(post.blocks) ? post.blocks : [];
        const refs = collectRefs(blocks);
        const products = await productsFor(refs.prod);
        const categories = await categoriesFor(refs.cat);

        // TOC from heading blocks
        const toc = blocks.filter(function (b) { return b.type === 'heading'; }).map(function (b) { return { level: b.level, text: csblocks.plainText(b.content), id: b.id }; });
        const tocHtml = csrender.tocHtml(toc);

        // related: manual overrides first, else latest same-type/category
        let relArticles = [];
        const man = (post.related && typeof post.related === 'object') ? post.related : {};
        relArticles = (await pool.query(
          "SELECT type,slug,title,excerpt,featured_image,reading_time,published_at FROM cs_posts WHERE status='published' AND id<>$1 AND (category_id=$2 OR type=$3) ORDER BY COALESCE(published_at,created_at) DESC LIMIT 3",
          [post.id, post.category_id, post.type])).rows;
        let relatedHtml = '';
        if (relArticles.length) relatedHtml += '<h3>Keep reading</h3><div class="cl-grid">' + relArticles.map(function (p) { return cardHtml(p, base); }).join('') + '</div>';
        const relProd = Object.values(products).filter(function (v, i, a) { return a.indexOf(v) === i; }).slice(0, 3);
        if (relProd.length) relatedHtml += '<h3 style="margin-top:26px">Related products</h3><div class="cs-pgrid">' + relProd.map(csrender.productCard).join('') + '</div>';
        if (relatedHtml) relatedHtml = '<div class="cs-related">' + relatedHtml + '</div>';

        const bodyHtml = csrender.renderBlocks(blocks, { products: products, categories: categories, waNumber: s.waNumber, tocHtml: tocHtml, relatedHtml: relatedHtml });

        // SEO + JSON-LD
        const url = base ? (base + canon) : canon;
        const ogImg = seo.ogImage || post.featured_image || '';
        const ogTags = [
          '<meta property="og:type" content="article">',
          '<meta property="og:title" content="' + esc(seo.ogTitle || post.title) + '">',
          '<meta property="og:description" content="' + esc(seo.ogDescription || post.excerpt || '') + '">',
          '<meta property="og:url" content="' + esc(url) + '">',
          ogImg ? ('<meta property="og:image" content="' + esc(/^https?:/.test(ogImg) ? ogImg : (base + ogImg)) + '">') : '',
          '<meta name="twitter:card" content="summary_large_image">',
          '<meta name="twitter:title" content="' + esc(seo.ogTitle || post.title) + '">',
          '<meta name="twitter:description" content="' + esc(seo.ogDescription || post.excerpt || '') + '">'
        ].filter(Boolean).join('\n');

        const faqItems = blocks.filter(function (b) { return b.type === 'faq'; }).reduce(function (acc, b) { return acc.concat(b.items || []); }, []);
        const ld = [{
          '@context': 'https://schema.org', '@type': post.type === 'tutorial' ? 'HowTo' : (post.type === 'news' ? 'NewsArticle' : 'BlogPosting'),
          headline: post.title, description: post.excerpt || '', datePublished: post.published_at, dateModified: post.updated_at,
          author: { '@type': 'Organization', name: authorName }, publisher: { '@type': 'Organization', name: s.siteName },
          mainEntityOfPage: url, image: ogImg ? [/^https?:/.test(ogImg) ? ogImg : (base + ogImg)] : undefined
        }, {
          '@context': 'https://schema.org', '@type': 'BreadcrumbList', itemListElement: [
            { '@type': 'ListItem', position: 1, name: 'Home', item: base || '/' },
            { '@type': 'ListItem', position: 2, name: PREFIX_TITLE[prefixOf(post.type)] || 'Blog', item: (base || '') + '/' + prefixOf(post.type) },
            { '@type': 'ListItem', position: 3, name: post.title, item: url }
          ]
        }];
        if (faqItems.length) ld.push({ '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: faqItems.map(function (f) { return { '@type': 'Question', name: csblocks.plainText(f.q), acceptedAnswer: { '@type': 'Answer', text: csblocks.plainText(f.a) } }; }) });
        const jsonLd = JSON.stringify(ld).replace(/</g, '\\u003c');

        // view count (fire and forget)
        pool.query('UPDATE cs_posts SET views=COALESCE(views,0)+1 WHERE id=$1', [post.id]).catch(function () {});
        pool.query("INSERT INTO cs_events(post_id,kind,meta) VALUES($1,'view',$2)", [post.id, JSON.stringify({ ref: req.get('referer') || '' })]).catch(function () {});

        res.render('content_article', Object.assign({
          title: (seo.title || post.title) + ' · ' + s.siteName,
          metaDescription: seo.description || post.excerpt || '',
          canonicalUrl: seo.canonical || url,
          robotsMeta: seo.robots || 'index,follow',
          ogTags: ogTags, jsonLd: jsonLd,
          post: post, authorName: authorName, typeLabel: TYPE_LABEL[post.type] || 'Article',
          prefixTitle: PREFIX_TITLE[prefixOf(post.type)] || 'Blog', prefix: prefixOf(post.type),
          bodyHtml: bodyHtml, tocHtml: tocHtml, relatedHtml: relatedHtml, updated: dstr(post.updated_at || post.published_at)
        }, s));
      } catch (e) { res.status(500).send('Article error: ' + e.message); }
    };
  }

  Object.keys(PREFIX_TYPES).forEach(function (prefix) {
    router.get('/' + prefix, listHandler(prefix));
    router.get('/' + prefix + '/:slug', articleHandler(prefix));
  });

  return router;
};
