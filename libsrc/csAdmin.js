'use strict';
/* Content Studio — ADMIN (light theme, matches /admin). Mounted at /admin, all
   routes under /cstudio. Import-first workflow: paste a content-package JSON
   (drafted in ChatGPT), validate via csblocks, upsert into cs_posts; plus a full
   metadata/SEO editor, posts list, redirects manager and dashboard. Drafts are
   previewable at their live URL for the logged-in admin (see routes/content.js). */
const express = require('express');
const B = require('../lib/csblocks');

module.exports = function (pool) {
  const router = express.Router();

  const TYPES = ['article', 'guide', 'tutorial', 'review', 'comparison', 'buying_guide', 'news', 'troubleshooting', 'faq', 'knowledge'];
  const TYPE_PREFIX = { article: 'blog', news: 'news', guide: 'guides', tutorial: 'tutorials', review: 'reviews', comparison: 'comparisons', buying_guide: 'buying-guides', troubleshooting: 'troubleshooting', faq: 'knowledge', knowledge: 'knowledge' };
  const TYPE_LABEL = { article: 'Article', news: 'News', guide: 'Guide', tutorial: 'Tutorial', review: 'Review', comparison: 'Comparison', buying_guide: 'Buying Guide', troubleshooting: 'Troubleshooting', faq: 'Knowledge', knowledge: 'Knowledge' };
  const prefixOf = function (t) { return TYPE_PREFIX[t] || 'blog'; };
  const pathOf = function (p) { return '/' + prefixOf(p.type) + '/' + p.slug; };

  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  function dtLocal(d) { try { if (!d) return ''; const x = new Date(d); const p = function (n) { return String(n).padStart(2, '0'); }; return x.getFullYear() + '-' + p(x.getMonth() + 1) + '-' + p(x.getDate()) + 'T' + p(x.getHours()) + ':' + p(x.getMinutes()); } catch (e) { return ''; } }

  const body = express.urlencoded({ extended: false, limit: '2mb' });

  async function resolveCategoryId(name) {
    if (!name) return null;
    const slug = B.slugify(name); if (!slug) return null;
    const hit = (await pool.query('SELECT id FROM cs_categories WHERE slug=$1', [slug])).rows[0];
    if (hit) return hit.id;
    const ins = (await pool.query('INSERT INTO cs_categories(slug,name) VALUES($1,$2) ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name RETURNING id', [slug, name])).rows[0];
    return ins.id;
  }
  async function linkTags(postId, tags) {
    await pool.query('DELETE FROM cs_post_tags WHERE post_id=$1', [postId]);
    const seen = {};
    for (const t of (tags || [])) {
      const slug = B.slugify(t); if (!slug || seen[slug]) continue; seen[slug] = 1;
      const tr = (await pool.query('INSERT INTO cs_tags(slug,name) VALUES($1,$2) ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name RETURNING id', [slug, t])).rows[0];
      await pool.query('INSERT INTO cs_post_tags(post_id,tag_id) VALUES($1,$2)', [postId, tr.id]);
    }
  }
  async function authors() { return (await pool.query('SELECT id,name,role FROM cs_authors ORDER BY id')).rows; }
  async function catName(id) { if (!id) return ''; const r = (await pool.query('SELECT name FROM cs_categories WHERE id=$1', [id])).rows[0]; return r ? r.name : ''; }
  async function tagString(postId) { const r = (await pool.query('SELECT t.name FROM cs_post_tags pt JOIN cs_tags t ON t.id=pt.tag_id WHERE pt.post_id=$1 ORDER BY t.name', [postId])).rows; return r.map(function (x) { return x.name; }).join(', '); }

  // ---------- dashboard ----------
  router.get('/cstudio', auth, async function (req, res) {
    const s = (await pool.query("SELECT count(*)::int total, count(*) FILTER (WHERE status='published')::int pub, count(*) FILTER (WHERE status='draft')::int draft, count(*) FILTER (WHERE status='scheduled')::int sched, COALESCE(sum(views),0)::int views FROM cs_posts")).rows[0];
    const recent = (await pool.query('SELECT id,type,slug,title,status,views,updated_at FROM cs_posts ORDER BY updated_at DESC LIMIT 8')).rows;
    res.render('admin/cs_dashboard', { active: 'cs_dash', title: 'Content Studio', stats: s, recent: recent, prefixOf: prefixOf, TYPE_LABEL: TYPE_LABEL, flash: req.query.ok || null });
  });

  // ---------- posts list ----------
  router.get('/cstudio/posts', auth, async function (req, res) {
    const q = (req.query.q || '').trim();
    const st = ['draft', 'published', 'scheduled'].indexOf(req.query.status) >= 0 ? req.query.status : '';
    const ty = TYPES.indexOf(req.query.type) >= 0 ? req.query.type : '';
    const where = [], params = [];
    if (q) { params.push('%' + q.toLowerCase() + '%'); where.push('(lower(title) LIKE $' + params.length + ' OR lower(slug) LIKE $' + params.length + ')'); }
    if (st) { params.push(st); where.push('status=$' + params.length); }
    if (ty) { params.push(ty); where.push('type=$' + params.length); }
    const w = where.length ? (' WHERE ' + where.join(' AND ')) : '';
    const rows = (await pool.query('SELECT id,type,slug,title,status,views,scheduled_at,updated_at FROM cs_posts' + w + ' ORDER BY updated_at DESC LIMIT 300', params)).rows;
    res.render('admin/cs_posts', { active: 'cs_posts', title: 'All posts', rows: rows, q: q, st: st, ty: ty, TYPES: TYPES, TYPE_LABEL: TYPE_LABEL, prefixOf: prefixOf, flash: req.query.ok || null });
  });

  // ---------- editor ----------
  function emptyPost() { return { id: 0, type: 'article', slug: '', title: '', excerpt: '', featured_image: '', author_id: null, category_id: null, status: 'draft', scheduled_at: null, blocks: [], seo: {} }; }
  async function renderEdit(res, post, extra) {
    const auths = await authors();
    const catNm = post.id ? await catName(post.category_id) : (post._catName || '');
    const tags = post.id ? await tagString(post.id) : (post._tags || '');
    res.render('admin/cs_edit', Object.assign({
      active: 'cs_posts', title: post.id ? ('Edit · ' + post.title) : 'New post',
      post: post, authors: auths, catName: catNm, tagStr: tags,
      TYPES: TYPES, TYPE_LABEL: TYPE_LABEL, prefixOf: prefixOf, dtLocal: dtLocal,
      blocksText: (extra && extra.blocksText != null) ? extra.blocksText : JSON.stringify(post.blocks || [], null, 2),
      errorMsg: (extra && extra.errorMsg) || null, warnings: (extra && extra.warnings) || [], flash: null
    }, extra || {}));
  }
  router.get('/cstudio/posts/new', auth, async function (req, res) { await renderEdit(res, emptyPost(), {}); });
  router.get('/cstudio/posts/:id/edit', auth, async function (req, res) {
    const p = (await pool.query('SELECT * FROM cs_posts WHERE id=$1', [parseInt(req.params.id, 10)])).rows[0];
    if (!p) return res.redirect('/admin/cstudio/posts?ok=' + encodeURIComponent('Post not found'));
    await renderEdit(res, p, {});
  });

  router.post('/cstudio/posts/save', auth, body, async function (req, res) {
    const id = req.body.id ? parseInt(req.body.id, 10) : 0;
    const status = ['draft', 'published', 'scheduled'].indexOf(req.body.status) >= 0 ? req.body.status : 'draft';
    const authorId = req.body.author_id ? parseInt(req.body.author_id, 10) : null;
    const tagsArr = (req.body.tags || '').split(',').map(function (s) { return s.trim(); }).filter(Boolean);
    let blocks;
    try { blocks = JSON.parse(req.body.blocks || '[]'); if (!Array.isArray(blocks)) throw new Error('top level must be an array of blocks'); }
    catch (e) {
      const draft = Object.assign(emptyPost(), { id: id, type: req.body.type, slug: req.body.slug, title: req.body.title, excerpt: req.body.excerpt, featured_image: req.body.featured_image, author_id: authorId, status: status, scheduled_at: req.body.scheduled_at, _catName: req.body.category, _tags: req.body.tags, seo: {} });
      return renderEdit(res, draft, { blocksText: req.body.blocks || '', errorMsg: 'Blocks JSON is invalid: ' + e.message });
    }
    const pkg = {
      type: req.body.type, title: req.body.title, slug: req.body.slug, excerpt: req.body.excerpt,
      category: req.body.category, tags: tagsArr, featuredImage: req.body.featured_image, blocks: blocks,
      seo: { title: req.body.seo_title, description: req.body.seo_description, canonical: req.body.seo_canonical, robots: req.body.seo_robots, ogImage: req.body.seo_ogimage, focus: req.body.seo_focus }
    };
    const r = B.normalizePackage(pkg);
    if (!r.ok) {
      const draft = Object.assign(emptyPost(), { id: id, type: req.body.type, slug: req.body.slug, title: req.body.title, excerpt: req.body.excerpt, featured_image: req.body.featured_image, author_id: authorId, status: status, scheduled_at: req.body.scheduled_at, _catName: req.body.category, _tags: req.body.tags, seo: pkg.seo });
      return renderEdit(res, draft, { blocksText: req.body.blocks || '', errorMsg: r.errors.join(' · '), warnings: r.warnings });
    }
    const p = r.post;
    const catId = await resolveCategoryId(p.category);
    const scheduledAt = (status === 'scheduled' && req.body.scheduled_at) ? new Date(req.body.scheduled_at) : null;
    try {
      let postId = id, oldPath = null, wasLive = false, oldType = null, oldSlug = null;
      if (id) {
        const ex = (await pool.query('SELECT slug,type,status,published_at FROM cs_posts WHERE id=$1', [id])).rows[0];
        if (!ex) throw new Error('post vanished');
        oldType = ex.type; oldSlug = ex.slug; wasLive = ex.status === 'published' || ex.status === 'scheduled';
        oldPath = '/' + prefixOf(ex.type) + '/' + ex.slug;
        let publishedAt = ex.published_at;
        if (status === 'published' && !publishedAt) publishedAt = new Date();
        if (status === 'draft') publishedAt = null;
        if (status === 'scheduled') publishedAt = null;
        await pool.query(
          "UPDATE cs_posts SET type=$1,slug=$2,title=$3,excerpt=$4,blocks=$5,featured_image=$6,author_id=$7,category_id=$8,status=$9,seo=$10,reading_time=$11,scheduled_at=$12,published_at=$13,updated_at=now() WHERE id=$14",
          [p.type, p.slug, p.title, p.excerpt, JSON.stringify(p.blocks), p.featured_image, authorId, catId, status, JSON.stringify(p.seo), p.reading_time, scheduledAt, publishedAt, id]);
      } else {
        const publishedAt = status === 'published' ? new Date() : null;
        const ins = (await pool.query(
          "INSERT INTO cs_posts(type,slug,title,excerpt,blocks,featured_image,author_id,category_id,status,seo,reading_time,scheduled_at,published_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id",
          [p.type, p.slug, p.title, p.excerpt, JSON.stringify(p.blocks), p.featured_image, authorId || 1, catId, status, JSON.stringify(p.seo), p.reading_time, scheduledAt, publishedAt])).rows[0];
        postId = ins.id;
      }
      await linkTags(postId, p.tags);
      // if a LIVE post's canonical path changed, auto-add a 301 so old links/indexing survive
      const newPath = '/' + prefixOf(p.type) + '/' + p.slug;
      if (id && wasLive && oldPath && oldPath !== newPath) {
        await pool.query('INSERT INTO cs_redirects(from_path,to_path,code) VALUES($1,$2,301) ON CONFLICT (from_path) DO UPDATE SET to_path=EXCLUDED.to_path,code=301', [oldPath, newPath]);
      }
      return res.redirect('/admin/cstudio/posts/' + postId + '/edit?ok=' + encodeURIComponent('Saved · ' + (status === 'published' ? 'published' : status)));
    } catch (e) {
      const msg = e.code === '23505' ? ('Slug "' + p.slug + '" is already used by another post. Choose a different slug.') : ('Save failed: ' + e.message);
      const draft = Object.assign(emptyPost(), { id: id, type: p.type, slug: p.slug, title: p.title, excerpt: p.excerpt, featured_image: p.featured_image, author_id: authorId, status: status, scheduled_at: req.body.scheduled_at, _catName: req.body.category, _tags: req.body.tags, seo: p.seo });
      return renderEdit(res, draft, { blocksText: JSON.stringify(p.blocks, null, 2), errorMsg: msg });
    }
  });

  router.post('/cstudio/posts/:id/status', auth, body, async function (req, res) {
    const id = parseInt(req.params.id, 10);
    const to = ['draft', 'published', 'scheduled'].indexOf(req.body.to) >= 0 ? req.body.to : 'draft';
    const ex = (await pool.query('SELECT published_at FROM cs_posts WHERE id=$1', [id])).rows[0];
    if (!ex) return res.redirect('/admin/cstudio/posts');
    let publishedAt = ex.published_at;
    if (to === 'published' && !publishedAt) publishedAt = new Date();
    if (to !== 'published') publishedAt = null;
    await pool.query('UPDATE cs_posts SET status=$1,published_at=$2,updated_at=now() WHERE id=$3', [to, publishedAt, id]);
    res.redirect(req.get('referer') && req.get('referer').indexOf('/edit') >= 0 ? ('/admin/cstudio/posts/' + id + '/edit?ok=' + encodeURIComponent('Status → ' + to)) : ('/admin/cstudio/posts?ok=' + encodeURIComponent('Status → ' + to)));
  });

  router.post('/cstudio/posts/:id/delete', auth, body, async function (req, res) {
    const id = parseInt(req.params.id, 10);
    const ex = (await pool.query('SELECT slug,type,status FROM cs_posts WHERE id=$1', [id])).rows[0];
    if (ex && ex.status === 'published' && req.body.redirect_to) {
      const from = '/' + prefixOf(ex.type) + '/' + ex.slug;
      await pool.query('INSERT INTO cs_redirects(from_path,to_path,code) VALUES($1,$2,301) ON CONFLICT (from_path) DO UPDATE SET to_path=EXCLUDED.to_path', [from, req.body.redirect_to]);
    }
    await pool.query('DELETE FROM cs_posts WHERE id=$1', [id]);
    res.redirect('/admin/cstudio/posts?ok=' + encodeURIComponent('Post deleted'));
  });

  // ---------- import ----------
  router.get('/cstudio/import', auth, function (req, res) {
    res.render('admin/cs_import', { active: 'cs_import', title: 'Import content', result: null, raw: '', flash: req.query.ok || null });
  });
  router.post('/cstudio/import', auth, body, async function (req, res) {
    const raw = req.body.json || '';
    const publishNow = !!req.body.publish;
    let pkg;
    try { pkg = JSON.parse(raw); }
    catch (e) { return res.render('admin/cs_import', { active: 'cs_import', title: 'Import content', result: { ok: false, errors: ['Not valid JSON: ' + e.message] }, raw: raw, flash: null }); }
    const list = Array.isArray(pkg) ? pkg : [pkg];
    const out = [];
    for (const one of list) {
      const r = B.normalizePackage(one);
      if (!r.ok) { out.push({ ok: false, title: (one && one.title) || '(untitled)', errors: r.errors, warnings: r.warnings }); continue; }
      const p = r.post;
      try {
        const catId = await resolveCategoryId(p.category);
        const status = publishNow ? 'published' : 'draft';
        const ex = (await pool.query('SELECT id,published_at FROM cs_posts WHERE slug=$1', [p.slug])).rows[0];
        let postId;
        if (ex) {
          const publishedAt = publishNow ? (ex.published_at || new Date()) : ex.published_at;
          await pool.query("UPDATE cs_posts SET type=$1,title=$2,excerpt=$3,blocks=$4,featured_image=$5,category_id=$6,seo=$7,reading_time=$8,status=CASE WHEN $9 THEN 'published' ELSE status END,published_at=$10,updated_at=now() WHERE id=$11",
            [p.type, p.title, p.excerpt, JSON.stringify(p.blocks), p.featured_image, catId, JSON.stringify(p.seo), p.reading_time, publishNow, publishedAt, ex.id]);
          postId = ex.id;
        } else {
          const publishedAt = publishNow ? new Date() : null;
          const ins = (await pool.query("INSERT INTO cs_posts(type,slug,title,excerpt,blocks,featured_image,author_id,category_id,status,seo,reading_time,published_at) VALUES($1,$2,$3,$4,$5,$6,1,$7,$8,$9,$10,$11) RETURNING id",
            [p.type, p.slug, p.title, p.excerpt, JSON.stringify(p.blocks), p.featured_image, catId, status, JSON.stringify(p.seo), p.reading_time, publishedAt])).rows[0];
          postId = ins.id;
        }
        await linkTags(postId, p.tags);
        out.push({ ok: true, id: postId, title: p.title, slug: p.slug, type: p.type, path: pathOf(p), status: status, existed: !!ex, warnings: r.warnings, blocks: p.blocks.length, reading: p.reading_time });
      } catch (e) {
        out.push({ ok: false, title: p.title, errors: [e.code === '23505' ? 'Slug already in use' : e.message] });
      }
    }
    res.render('admin/cs_import', { active: 'cs_import', title: 'Import content', result: { ok: out.every(function (o) { return o.ok; }), items: out }, raw: out.every(function (o) { return o.ok; }) ? '' : raw, flash: null });
  });

  // ---------- redirects ----------
  router.get('/cstudio/redirects', auth, async function (req, res) {
    const rows = (await pool.query('SELECT id,from_path,to_path,code,created_at FROM cs_redirects ORDER BY created_at DESC')).rows;
    res.render('admin/cs_redirects', { active: 'cs_redirects', title: 'Redirects', rows: rows, flash: req.query.ok || null });
  });
  router.post('/cstudio/redirects/save', auth, body, async function (req, res) {
    let from = (req.body.from_path || '').trim(), to = (req.body.to_path || '').trim();
    const code = [301, 302].indexOf(parseInt(req.body.code, 10)) >= 0 ? parseInt(req.body.code, 10) : 301;
    if (from && from[0] !== '/') from = '/' + from;
    if (to && !/^https?:\/\//i.test(to) && to[0] !== '/') to = '/' + to;
    if (!from || !to) return res.redirect('/admin/cstudio/redirects?ok=' + encodeURIComponent('From and To are required'));
    await pool.query('INSERT INTO cs_redirects(from_path,to_path,code) VALUES($1,$2,$3) ON CONFLICT (from_path) DO UPDATE SET to_path=EXCLUDED.to_path,code=EXCLUDED.code', [from, to, code]);
    res.redirect('/admin/cstudio/redirects?ok=' + encodeURIComponent('Redirect saved'));
  });
  router.post('/cstudio/redirects/:id/delete', auth, body, async function (req, res) {
    await pool.query('DELETE FROM cs_redirects WHERE id=$1', [parseInt(req.params.id, 10)]);
    res.redirect('/admin/cstudio/redirects?ok=' + encodeURIComponent('Redirect removed'));
  });

  return router;
};
