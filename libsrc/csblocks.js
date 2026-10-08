'use strict';
/* Content Studio — block model: validate + sanitize + normalize a content
   package into stored blocks, plus helpers (slug, reading time, TOC, anchors).
   Security: all user text is HTML-escaped first; a tiny whitelist of safe inline
   tags is then selectively restored (escape-then-restore = XSS-safe). Unknown
   block types are dropped with a warning. No raw/custom HTML is trusted in v1. */

function escapeHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// Allow only a safe inline subset: b/strong/i/em/u/s/mark/code/sup/sub, <br>, and
// http(s)-or-site-relative anchors. Everything else stays escaped (inert).
function sanitizeInline(s) {
  s = escapeHtml(s);
  ['b', 'strong', 'i', 'em', 'u', 's', 'mark', 'code', 'sup', 'sub'].forEach(function (t) {
    s = s.replace(new RegExp('&lt;' + t + '&gt;', 'g'), '<' + t + '>')
      .replace(new RegExp('&lt;/' + t + '&gt;', 'g'), '</' + t + '>');
  });
  s = s.replace(/&lt;br\s*\/?&gt;/gi, '<br>');
  s = s.replace(/&lt;a href=&quot;((?:https?:\/\/|\/|mailto:|tel:)[^"&]+)&quot;&gt;/gi, function (m, u) {
    const ext = /^https?:\/\//i.test(u);
    return '<a href="' + u + '"' + (ext ? ' target="_blank" rel="noopener nofollow"' : '') + '>';
  }).replace(/&lt;\/a&gt;/gi, '</a>');
  return s;
}

function slugify(s) {
  return String(s || '').toLowerCase().trim()
    .replace(/['"]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80) || 'section';
}

function plainText(s) { return String(s || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim(); }

const CALLOUT_VARIANTS = { callout: 'info', info: 'info', tip: 'tip', note: 'info', alert: 'warn', warning: 'warn', warn: 'warn', success: 'ok', danger: 'bad', error: 'bad' };

// Normalize one block. Returns a clean block object or null (dropped).
function normBlock(b, ctx) {
  if (!b || typeof b !== 'object') return null;
  const t = String(b.type || '').toLowerCase().replace(/[^a-z_]/g, '');
  const warn = ctx.warnings;
  switch (t) {
    case 'heading': {
      let lvl = parseInt(b.level, 10); if (!(lvl >= 2 && lvl <= 4)) lvl = 2;
      const text = plainText(b.content || b.text);
      if (!text) return null;
      let id = slugify(b.id || text);
      while (ctx.ids.has(id)) id = id + '-' + (++ctx.idc);
      ctx.ids.add(id);
      ctx.toc.push({ level: lvl, text: text, id: id });
      return { type: 'heading', level: lvl, content: sanitizeInline(b.content || b.text), id: id };
    }
    case 'paragraph': case 'text': case 'richtext': {
      const html = sanitizeInline(b.content || b.html || b.text);
      if (!plainText(html)) return null;
      ctx.words += plainText(html).split(' ').length;
      return { type: 'paragraph', content: html };
    }
    case 'quote': {
      const c = sanitizeInline(b.content || b.text); if (!plainText(c)) return null;
      return { type: 'quote', content: c, cite: b.cite ? escapeHtml(b.cite) : '' };
    }
    case 'list': case 'ul': case 'ol': {
      const items = (Array.isArray(b.items) ? b.items : []).map(function (x) { return sanitizeInline(typeof x === 'string' ? x : (x && (x.content || x.text) || '')); }).filter(function (x) { return plainText(x); });
      if (!items.length) return null;
      const ordered = !!b.ordered || t === 'ol';
      ctx.words += items.reduce(function (n, x) { return n + plainText(x).split(' ').length; }, 0);
      return { type: 'list', ordered: ordered, items: items };
    }
    case 'callout': case 'info': case 'tip': case 'note': case 'alert': case 'warning': case 'warn': case 'success': case 'danger': case 'error': {
      const variant = CALLOUT_VARIANTS[t] || CALLOUT_VARIANTS[String(b.variant || '').toLowerCase()] || 'info';
      const c = sanitizeInline(b.content || b.text); if (!plainText(c) && !b.title) return null;
      return { type: 'callout', variant: variant, title: b.title ? escapeHtml(b.title) : '', content: c };
    }
    case 'proscons': case 'pros_cons': {
      const pros = (Array.isArray(b.pros) ? b.pros : []).map(function (x) { return sanitizeInline(x); }).filter(function (x) { return plainText(x); });
      const cons = (Array.isArray(b.cons) ? b.cons : []).map(function (x) { return sanitizeInline(x); }).filter(function (x) { return plainText(x); });
      if (!pros.length && !cons.length) return null;
      return { type: 'proscons', pros: pros, cons: cons };
    }
    case 'steps': case 'howto': {
      const items = (Array.isArray(b.items) ? b.items : b.steps || []).map(function (x) {
        if (typeof x === 'string') return { title: '', content: sanitizeInline(x) };
        return { title: x && x.title ? escapeHtml(x.title) : '', content: sanitizeInline(x && (x.content || x.text) || '') };
      }).filter(function (x) { return plainText(x.content) || x.title; });
      if (!items.length) return null;
      return { type: 'steps', items: items };
    }
    case 'faq': {
      const items = (Array.isArray(b.items) ? b.items : []).map(function (x) {
        return { q: escapeHtml(x && (x.q || x.question) || ''), a: sanitizeInline(x && (x.a || x.answer) || '') };
      }).filter(function (x) { return x.q && plainText(x.a); });
      if (!items.length) return null;
      ctx.faq = (ctx.faq || []).concat(items);
      return { type: 'faq', items: items };
    }
    case 'table': {
      const headers = (Array.isArray(b.headers) ? b.headers : []).map(function (x) { return sanitizeInline(x); });
      const rows = (Array.isArray(b.rows) ? b.rows : []).map(function (r) { return (Array.isArray(r) ? r : []).map(function (c) { return sanitizeInline(c); }); }).filter(function (r) { return r.length; });
      if (!rows.length) return null;
      return { type: 'table', headers: headers, rows: rows, caption: b.caption ? escapeHtml(b.caption) : '', highlight: Array.isArray(b.highlightRows) ? b.highlightRows : [] };
    }
    case 'image': case 'featured_banner': {
      const src = cleanUrl(b.src || b.url); if (!src) return null;
      return { type: 'image', src: src, alt: escapeHtml(b.alt || ''), caption: b.caption ? escapeHtml(b.caption) : '', banner: t === 'featured_banner' };
    }
    case 'imagetext': case 'image_text': {
      const src = cleanUrl(b.src || b.url); if (!src) return null;
      return { type: 'imagetext', src: src, alt: escapeHtml(b.alt || ''), content: sanitizeInline(b.content || b.text), position: (b.position === 'right' ? 'right' : 'left') };
    }
    case 'youtube': case 'video': case 'video_embed': case 'youtube_embed': {
      const url = String(b.url || b.src || '');
      const yt = url.match(/(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/);
      if (yt) return { type: 'youtube', id: yt[1], caption: b.caption ? escapeHtml(b.caption) : '' };
      const vm = url.match(/vimeo\.com\/(\d+)/); if (vm) return { type: 'vimeo', id: vm[1], caption: b.caption ? escapeHtml(b.caption) : '' };
      warn.push('dropped unsupported video embed'); return null;
    }
    case 'button': {
      return { type: 'button', button: normButton(b) };
    }
    case 'cta': {
      const btn = b.button ? normButton(b.button) : (b.label ? normButton(b) : null);
      return { type: 'cta', title: b.title ? escapeHtml(b.title) : '', content: sanitizeInline(b.content || b.text || ''), button: btn };
    }
    case 'product': case 'productcard': case 'product_card': {
      const ref = b.productId || b.product_id || b.slug || b.id; if (!ref) return null;
      return { type: 'productcard', ref: String(ref) };
    }
    case 'productgrid': case 'product_grid': {
      const refs = (Array.isArray(b.products) ? b.products : b.ids || []).map(String).filter(Boolean);
      if (!refs.length) return null;
      return { type: 'productgrid', refs: refs };
    }
    case 'category': case 'categorycard': case 'category_card': {
      const ref = b.slug || b.id; if (!ref) return null;
      return { type: 'categorycard', ref: String(ref) };
    }
    case 'toc': case 'table_of_contents': return { type: 'toc' };
    case 'divider': case 'hr': return { type: 'divider' };
    case 'spacer': return { type: 'spacer', size: ['sm', 'lg'].indexOf(b.size) >= 0 ? b.size : 'md' };
    case 'code': return { type: 'code', lang: slugify(b.lang || b.language || 'text'), content: escapeHtml(b.content || b.code || '') };
    case 'related': return { type: 'related' };
    case 'statistics': case 'stats': {
      const items = (Array.isArray(b.items) ? b.items : []).map(function (x) { return { value: escapeHtml(x && x.value || ''), label: escapeHtml(x && x.label || '') }; }).filter(function (x) { return x.value; });
      if (!items.length) return null; return { type: 'stats', items: items };
    }
    default:
      warn.push('dropped unknown block type: ' + (b.type || '(none)')); return null;
  }
}

function cleanUrl(u) {
  u = String(u || '').trim();
  if (/^https?:\/\//i.test(u)) return u;
  if (/^\/[^\s]*$/.test(u)) return u;             // site-relative
  if (/^[\w.\-\/]+\.(png|jpe?g|webp|gif|svg|avif)$/i.test(u)) return '/static/img/' + u.replace(/^\/+/, '');
  return '';
}

const BTN_DEST = ['product', 'plan', 'category', 'article', 'guide', 'tutorial', 'checkout', 'internal', 'external', 'whatsapp', 'download', 'custom'];
const BTN_STYLE = ['primary', 'dark', 'ghost', 'wa'];
function normButton(b) {
  const d = (b.destination && typeof b.destination === 'object') ? b.destination : {};
  const dtype = BTN_DEST.indexOf(String(d.type || b.destType || '').toLowerCase()) >= 0 ? String(d.type || b.destType).toLowerCase() : 'internal';
  return {
    label: escapeHtml(b.label || b.text || 'Learn more'),
    dest: {
      type: dtype,
      value: String(d.value || d.id || d.url || d.slug || b.url || '').slice(0, 300),
      waText: d.waText ? String(d.waText).slice(0, 300) : ''
    },
    style: BTN_STYLE.indexOf(String(b.style || '').toLowerCase()) >= 0 ? String(b.style).toLowerCase() : 'primary',
    size: ['sm', 'lg'].indexOf(String(b.size || '').toLowerCase()) >= 0 ? String(b.size).toLowerCase() : 'md',
    align: ['center', 'right'].indexOf(String(b.align || '').toLowerCase()) >= 0 ? String(b.align).toLowerCase() : 'left',
    icon: b.icon ? slugify(b.icon) : '',
    newTab: !!b.newTab || !!b.open_in_new_tab,
    rel: [b.nofollow ? 'nofollow' : '', b.sponsored ? 'sponsored' : ''].filter(Boolean).join(' '),
    track: b.trackingId ? String(b.trackingId).slice(0, 80).replace(/[^A-Za-z0-9_\-]/g, '') : '',
    utm: (b.utm && typeof b.utm === 'object') ? b.utm : null
  };
}

// Normalize a whole content package. Returns { ok, errors, warnings, post }.
function normalizePackage(pkg) {
  const errors = [], warnings = [];
  if (!pkg || typeof pkg !== 'object') return { ok: false, errors: ['package is not an object'], warnings: warnings };
  const title = String(pkg.title || '').trim();
  if (!title) errors.push('title is required');
  const type = slugify(pkg.type || 'article').replace(/-/g, '_');
  const allowed = ['article', 'guide', 'tutorial', 'review', 'comparison', 'buying_guide', 'news', 'troubleshooting', 'faq', 'knowledge'];
  const finalType = allowed.indexOf(type) >= 0 ? type : 'article';
  const slug = slugify(pkg.slug || title);
  const ctx = { ids: new Set(), idc: 0, toc: [], words: 0, warnings: warnings, faq: [] };
  const rawBlocks = Array.isArray(pkg.blocks) ? pkg.blocks : [];
  const blocks = rawBlocks.map(function (b) { return normBlock(b, ctx); }).filter(Boolean);
  if (!blocks.length) errors.push('no valid blocks');
  const readingTime = Math.max(1, Math.round(ctx.words / 200));
  const seoIn = (pkg.seo && typeof pkg.seo === 'object') ? pkg.seo : {};
  const seo = {
    title: String(seoIn.title || pkg.metaTitle || title).slice(0, 70),
    description: String(seoIn.description || pkg.metaDescription || pkg.excerpt || '').slice(0, 320),
    canonical: cleanUrl(seoIn.canonical || '') || '',
    robots: seoIn.robots || (seoIn.noindex ? 'noindex' : 'index') + ',' + (seoIn.nofollow ? 'nofollow' : 'follow'),
    ogImage: cleanUrl(seoIn.ogImage || seoIn.og_image || pkg.featuredImage || ''),
    ogTitle: String(seoIn.ogTitle || seoIn.title || title).slice(0, 90),
    ogDescription: String(seoIn.ogDescription || seoIn.description || pkg.excerpt || '').slice(0, 200),
    focus: String(seoIn.focus || '').slice(0, 120),
    secondary: Array.isArray(seoIn.secondary) ? seoIn.secondary.slice(0, 10).map(String) : []
  };
  const post = {
    type: finalType, slug: slug, title: title,
    excerpt: String(pkg.excerpt || seo.description || '').slice(0, 320),
    blocks: blocks,
    featured_image: cleanUrl(pkg.featuredImage || pkg.featured_image || ''),
    reading_time: readingTime,
    seo: seo,
    toc: ctx.toc,
    faq: ctx.faq,
    tags: Array.isArray(pkg.tags) ? pkg.tags.map(String).map(function (x) { return x.trim(); }).filter(Boolean).slice(0, 20) : [],
    category: pkg.category ? String(pkg.category).trim() : ''
  };
  return { ok: errors.length === 0, errors: errors, warnings: warnings, post: post };
}

module.exports = { normalizePackage, normBlock, normButton, sanitizeInline, escapeHtml, slugify, plainText, cleanUrl };
