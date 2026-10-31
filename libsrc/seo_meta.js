'use strict';
/* lib/seo_meta.js — pure SEO head/meta/schema builder for the Geo Page Engine.
 *
 * No DB, no I/O, no rendering engine. Given a resolved page context it returns
 * plain strings/objects the EJS template drops into <head>:
 *   - buildMeta(ctx)      -> { title, description, canonical, robots, og, twitter, hreflang[] }
 *   - buildJsonLd(ctx)    -> array of JSON-LD objects (BreadcrumbList, ItemList, FAQPage, Product, LocalBusiness)
 *   - renderHead(ctx)     -> a single HTML string with every <meta>/<link>/<script type=ld+json>
 *
 * Token templating is intentionally tiny: {location},{country},{region},{city},
 * {category},{intent},{demonym},{count},{site} — filled from ctx. Everything is
 * HTML/JSON escaped. Safe to require anywhere; it never throws on missing fields.
 */

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
function attr(s) { return esc(s); }
function clamp(s, n) { s = String(s == null ? '' : s).trim(); return s.length > n ? s.slice(0, n - 1).trimEnd() + '…' : s; }
function titleCase(s) { return String(s || '').replace(/\b\w/g, c => c.toUpperCase()); }

// Tiny {token} filler. Unknown tokens collapse to '' and extra spaces are squeezed.
function fill(tpl, tok) {
  if (!tpl) return '';
  return String(tpl)
    .replace(/\{(\w+)\}/g, (_, k) => (tok[k] != null ? String(tok[k]) : ''))
    .replace(/\s{2,}/g, ' ').replace(/\s+([,.;:!?])/g, '$1').trim();
}

// Absolute URL from a site base + path (path may already be absolute).
function abs(base, path) {
  if (!path) return base || '';
  if (/^https?:\/\//i.test(path)) return path;
  base = (base || '').replace(/\/+$/, '');
  return base + '/' + String(path).replace(/^\/+/, '');
}

// Build the {token} bag from a resolved context.
function tokens(ctx) {
  ctx = ctx || {};
  const loc = ctx.location || {};
  const country = ctx.country || {};
  const region = ctx.region || {};
  const city = ctx.city || {};
  const intent = ctx.intent || {};
  return {
    site: ctx.siteName || 'Galaxy Zayron',
    location: loc.name || '',
    locationType: loc.type || '',
    country: country.name || '',
    region: region.name || '',
    city: city.name || '',
    category: ctx.categoryName || '',
    intent: intent.name || '',
    demonym: loc.demonym || country.demonym || '',
    count: ctx.products ? ctx.products.length : (ctx.count || 0),
    year: new Date().getUTCFullYear()
  };
}

/* ----------------------------- meta ----------------------------- */
function buildMeta(ctx) {
  ctx = ctx || {};
  const tok = tokens(ctx);
  const intent = ctx.intent || {};
  const page = ctx.page || {};

  // Priority: explicit page override -> intent template -> sensible default.
  let title = page.seo_title
    || fill(intent.title_template, tok)
    || defaultTitle(ctx, tok);
  let desc = page.seo_description
    || fill(intent.meta_template, tok)
    || defaultDesc(ctx, tok);

  title = clamp(title, 65);
  desc = clamp(desc, 158);

  const base = ctx.siteUrl || '';
  const canonical = page.canonical_url || abs(base, ctx.path);

  // robots reflects the gate decision; default index,follow.
  const idx = (ctx.indexing || 'INDEX').toUpperCase();
  const robots = (idx === 'NOINDEX')
    ? 'noindex,follow'
    : 'index,follow,max-image-preview:large,max-snippet:-1';

  const ogImage = ctx.ogImage ? abs(base, ctx.ogImage) : (ctx.siteImage ? abs(base, ctx.siteImage) : '');

  return {
    title, description: desc, canonical, robots,
    lang: ctx.lang || 'en',
    og: {
      'og:type': ctx.ogType || 'website',
      'og:site_name': tok.site,
      'og:title': title,
      'og:description': desc,
      'og:url': canonical,
      'og:locale': (ctx.lang || 'en').replace('-', '_'),
      'og:image': ogImage
    },
    twitter: {
      'twitter:card': ogImage ? 'summary_large_image' : 'summary',
      'twitter:title': title,
      'twitter:description': desc,
      'twitter:image': ogImage
    },
    hreflang: hreflangLinks(ctx)
  };
}

function defaultTitle(ctx, tok) {
  const parts = [];
  if (tok.category) parts.push(tok.category);
  if (tok.intent && !/best|local|availability/i.test(tok.intent)) parts.push(tok.intent);
  if (tok.location) parts.push('in ' + tok.location);
  let t = parts.join(' ').trim();
  if (!t) t = tok.site;
  else t += ' | ' + tok.site;
  return t;
}
function defaultDesc(ctx, tok) {
  const what = tok.category || 'premium digital subscriptions';
  const where = tok.location ? (' in ' + tok.location) : '';
  const n = tok.count ? (tok.count + '+ ') : '';
  return `Get ${n}${what}${where} from ${tok.site}. Instant delivery, local payment options, and ${tok.year} pricing. Order in minutes.`;
}

/* --------------------------- hreflang --------------------------- */
// One alternate per language the location declares, + x-default. Safe no-op when
// the site is single-language (returns []), so the template emits nothing.
function hreflangLinks(ctx) {
  ctx = ctx || {};
  const loc = ctx.location || {};
  let langs = Array.isArray(loc.languages) ? loc.languages.slice() : [];
  if (!langs.length && Array.isArray(ctx.siteLanguages)) langs = ctx.siteLanguages.slice();
  if (langs.length < 2) return []; // nothing meaningful to declare
  const base = ctx.siteUrl || '';
  const self = abs(base, ctx.path);
  const out = langs.map(l => ({ lang: l, url: self }));           // same URL; refine when per-lang paths exist
  out.push({ lang: 'x-default', url: self });
  return out;
}

/* --------------------------- JSON-LD ---------------------------- */
function buildJsonLd(ctx) {
  ctx = ctx || {};
  const base = ctx.siteUrl || '';
  const tok = tokens(ctx);
  const out = [];

  // BreadcrumbList
  if (Array.isArray(ctx.breadcrumbs) && ctx.breadcrumbs.length) {
    out.push({
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: ctx.breadcrumbs.map((b, i) => ({
        '@type': 'ListItem', position: i + 1, name: b.name,
        item: abs(base, b.url)
      }))
    });
  }

  // ItemList of recommended products
  if (Array.isArray(ctx.products) && ctx.products.length) {
    out.push({
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      name: clamp((ctx.page && ctx.page.seo_title) || defaultTitle(ctx, tok), 110),
      numberOfItems: ctx.products.length,
      itemListElement: ctx.products.slice(0, 30).map((p, i) => ({
        '@type': 'ListItem', position: i + 1,
        name: p.name, url: abs(base, p.url || '')
      }))
    });
    // Per-product Product/Offer (bounded) — only when a price is known.
    ctx.products.slice(0, 12).forEach(p => {
      if (p.price == null && p.priceUsd == null) return;
      const offer = {
        '@type': 'Offer',
        priceCurrency: p.currency || (p.priceUsd != null ? 'USD' : 'PKR'),
        price: String(p.priceUsd != null ? p.priceUsd : p.price),
        availability: 'https://schema.org/' + (p.available === false ? 'OutOfStock' : 'InStock'),
        url: abs(base, p.url || ctx.path)
      };
      out.push({
        '@context': 'https://schema.org', '@type': 'Product',
        name: p.name,
        description: clamp(p.description || (p.name + ' — ' + (tok.location || tok.site)), 200),
        brand: { '@type': 'Brand', name: p.brand || tok.site },
        offers: offer
      });
    });
  }

  // FAQPage
  if (Array.isArray(ctx.faq) && ctx.faq.length) {
    out.push({
      '@context': 'https://schema.org', '@type': 'FAQPage',
      mainEntity: ctx.faq.map(f => ({
        '@type': 'Question', name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a }
      }))
    });
  }

  // LocalBusiness / Service area — only when we actually serve a place.
  if (ctx.location && ctx.location.name && ctx.includeLocalBusiness !== false) {
    const lb = {
      '@context': 'https://schema.org',
      '@type': 'OnlineStore',
      name: tok.site,
      url: base || undefined,
      areaServed: { '@type': 'Place', name: ctx.location.name }
    };
    if (ctx.location.latitude != null && ctx.location.longitude != null) {
      lb.areaServed.geo = { '@type': 'GeoCoordinates', latitude: ctx.location.latitude, longitude: ctx.location.longitude };
    }
    out.push(lb);
  }

  return out;
}

/* --------------------------- renderHead ------------------------- */
// Assembles the full <head> SEO block as one HTML string. The template includes
// this verbatim; nothing else is required for correct meta/schema.
function renderHead(ctx) {
  const m = buildMeta(ctx);
  const ld = buildJsonLd(ctx);
  const L = [];
  L.push('<title>' + esc(m.title) + '</title>');
  L.push('<meta name="description" content="' + attr(m.description) + '">');
  L.push('<meta name="robots" content="' + attr(m.robots) + '">');
  if (m.canonical) L.push('<link rel="canonical" href="' + attr(m.canonical) + '">');
  Object.keys(m.og).forEach(k => { if (m.og[k]) L.push('<meta property="' + attr(k) + '" content="' + attr(m.og[k]) + '">'); });
  Object.keys(m.twitter).forEach(k => { if (m.twitter[k]) L.push('<meta name="' + attr(k) + '" content="' + attr(m.twitter[k]) + '">'); });
  m.hreflang.forEach(h => L.push('<link rel="alternate" hreflang="' + attr(h.lang) + '" href="' + attr(h.url) + '">'));
  ld.forEach(obj => L.push('<script type="application/ld+json">' + jsonLdSafe(obj) + '</script>'));
  return L.join('\n');
}

// JSON for inline <script>: escape </ so a "</script>" inside data can't close the tag.
function jsonLdSafe(obj) {
  return JSON.stringify(obj).replace(/<\/(script)/gi, '<\\/$1').replace(/<!--/g, '<\\!--');
}

module.exports = { buildMeta, buildJsonLd, hreflangLinks, renderHead, _fill: fill, _abs: abs, _esc: esc };
