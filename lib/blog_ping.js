'use strict';
/* lib/blog_ping.js — fire-and-forget IndexNow ping for a single blog post, the instant it is
 * published, edited, or removed. Reuses lib/indexnow (Bing / Yandex / Seznam / IndexNow network).
 * Never throws and never blocks the request: callers invoke it without awaiting.
 * Post URL mirrors the canonical scheme in routes/content.js + routes/sitemap.js. */
const indexnow = require('./indexnow');

const TYPE_PREFIX = {
  article: 'blog', news: 'news', guide: 'guides', tutorial: 'tutorials', review: 'reviews',
  comparison: 'comparisons', buying_guide: 'buying-guides', troubleshooting: 'troubleshooting',
  faq: 'knowledge', knowledge: 'knowledge'
};
function prefixOf(type) { return TYPE_PREFIX[type] || 'blog'; }

function normBase(base) {
  let b = String(base || '').trim().replace(/\/+$/, '');
  if (!b) return '';
  if (!/^https?:\/\//.test(b)) b = 'https://' + b;
  return b;
}

// base from env (SITE_URL / SITE_DOMAIN) or the request host, normalised to https://host
function baseFrom(req) {
  return normBase(process.env.SITE_URL || process.env.SITE_DOMAIN || (req && req.get ? ('https://' + req.get('host')) : 'galaxyzayron.store'));
}

// pingPost(pool, base, {type, slug}) -> submits the post URL + its hub to IndexNow. Fail-safe.
async function pingPost(pool, base, post) {
  try {
    const b = normBase(base);
    if (!b || !post || !post.slug) return null;
    const pre = prefixOf(post.type);
    const urls = [b + '/' + pre + '/' + post.slug, b + '/' + pre];
    return await indexnow.ping(pool, b, urls);
  } catch (e) { return null; }
}

module.exports = { pingPost, prefixOf, baseFrom, normBase, TYPE_PREFIX };
