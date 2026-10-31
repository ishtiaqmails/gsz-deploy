'use strict';
/* lib/sitemap.js — sitemap index + child sitemap generation.
 *
 * Two layers:
 *   pure XML builders (no I/O, unit-testable):
 *     urlset(entries)      -> <urlset> XML for up to 50k <url> entries
 *     sitemapindex(list)   -> <sitemapindex> XML pointing at child sitemaps
 *   DB collector (needs pool):
 *     collect(pool, opts)  -> { index, children: { 'geo-1.xml': xml, ... }, count }
 *
 * Source of truth for "what may be indexed" is seo_urls (indexable=TRUE) plus
 * PUBLISHED+INDEX geo_pages. NOTHING here registers an Express route — the route
 * is wired later so it can reuse/replace any existing /sitemap.xml without clobber.
 *
 * Standards: 50,000 URL / 50MB cap per file (we chunk at 45k for headroom).
 */
const CHUNK = 45000;
const NS = 'http://www.sitemaps.org/schemas/sitemap/0.9';

function xmlEsc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&apos;');
}
function iso(d) {
  if (!d) return null;
  try { return new Date(d).toISOString().slice(0, 10); } catch (e) { return null; }
}

// entries: [{ loc, lastmod?, changefreq?, priority? }]
function urlset(entries) {
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="' + NS + '">'];
  for (const e of (entries || [])) {
    if (!e || !e.loc) continue;
    lines.push('  <url>');
    lines.push('    <loc>' + xmlEsc(e.loc) + '</loc>');
    const lm = iso(e.lastmod);
    if (lm) lines.push('    <lastmod>' + lm + '</lastmod>');
    if (e.changefreq) lines.push('    <changefreq>' + xmlEsc(e.changefreq) + '</changefreq>');
    if (e.priority != null) lines.push('    <priority>' + Number(e.priority).toFixed(1) + '</priority>');
    lines.push('  </url>');
  }
  lines.push('</urlset>');
  return lines.join('\n');
}

// list: [{ loc, lastmod? }]
function sitemapindex(list) {
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<sitemapindex xmlns="' + NS + '">'];
  for (const s of (list || [])) {
    if (!s || !s.loc) continue;
    lines.push('  <sitemap>');
    lines.push('    <loc>' + xmlEsc(s.loc) + '</loc>');
    const lm = iso(s.lastmod);
    if (lm) lines.push('    <lastmod>' + lm + '</lastmod>');
    lines.push('  </sitemap>');
  }
  lines.push('</sitemapindex>');
  return lines.join('\n');
}

function chunk(arr, n) {
  const out = []; for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n)); return out;
}

/* ------------------------------ collector ------------------------------ */
// opts: { base, pathPrefix='/sitemaps', changefreq='weekly' }
async function collect(pool, opts) {
  opts = opts || {};
  const base = (opts.base || '').replace(/\/+$/, '');
  const prefix = opts.pathPrefix || '/sitemaps';
  const abs = (loc) => /^https?:\/\//i.test(loc) ? loc : base + '/' + String(loc).replace(/^\/+/, '');

  // 1) Indexable geo pages (authoritative for the engine's own pages).
  const geo = (await safe(pool,
    "SELECT slug, updated_at, published_at FROM geo_pages " +
    "WHERE status='PUBLISHED' AND indexing_status='INDEX' ORDER BY updated_at DESC")).rows || [];

  // 2) Anything else the registry marks indexable that isn't a geo page
  //    (products/categories/static), so the sitemap covers the whole site.
  const reg = (await safe(pool,
    "SELECT url, normalized_url, last_changed_at, crawl_priority FROM seo_urls " +
    "WHERE indexable IS TRUE AND (entity_type IS DISTINCT FROM 'geo_page') " +
    "ORDER BY crawl_priority DESC NULLS LAST")).rows || [];

  const seen = new Set();
  const entries = [];
  for (const g of geo) {
    const loc = abs(g.slug);
    if (seen.has(loc)) continue; seen.add(loc);
    entries.push({ loc, lastmod: g.updated_at || g.published_at, changefreq: opts.changefreq || 'weekly', priority: 0.7 });
  }
  for (const u of reg) {
    const loc = abs(u.url || u.normalized_url);
    if (!loc || seen.has(loc)) continue; seen.add(loc);
    entries.push({
      loc, lastmod: u.last_changed_at,
      changefreq: opts.changefreq || 'weekly',
      priority: priFrom(u.crawl_priority)
    });
  }

  const groups = chunk(entries, CHUNK);
  const children = {};
  const indexList = [];
  if (!groups.length) {
    children['sitemap-0.xml'] = urlset([]);
    indexList.push({ loc: abs(prefix.replace(/^\/+/, '') + '/sitemap-0.xml'), lastmod: new Date() });
  } else {
    groups.forEach((grp, i) => {
      const name = 'sitemap-' + i + '.xml';
      children[name] = urlset(grp);
      const newest = grp.reduce((m, e) => (e.lastmod && (!m || new Date(e.lastmod) > new Date(m))) ? e.lastmod : m, null);
      indexList.push({ loc: abs(prefix.replace(/^\/+/, '') + '/' + name), lastmod: newest || new Date() });
    });
  }
  return { index: sitemapindex(indexList), children, count: entries.length };
}

function priFrom(cp) {
  if (cp == null) return 0.5;
  const n = Number(cp);
  if (!isFinite(n)) return 0.5;
  // crawl_priority defaults around 100; map 0..200 -> 0.1..1.0
  return Math.max(0.1, Math.min(1.0, Math.round((n / 200) * 10) / 10));
}
async function safe(pool, sql, params) {
  try { return await pool.query(sql, params || []); } catch (e) { return { rows: [] }; }
}

module.exports = { urlset, sitemapindex, collect, _priFrom: priFrom, _chunk: chunk, CHUNK };
