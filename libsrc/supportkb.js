'use strict';
/* Live Support Bot — Knowledge Base engine (Stage 1).
   Self-contained: builds the bot's "brain" purely from the real site database — no external
   service, no API, no LLM. Catalog-first: products, plans, prices, stock-source, warranty,
   FAQs, downloads, categories, plus site settings. Cached in-memory with a short TTL and a
   manual invalidate() so it auto-refreshes and can be re-trained the instant the admin changes
   anything. Everything here is grounded in actual rows — nothing invented. */

let storefront = null; try { storefront = require('./storefront'); } catch (e) { /* settings optional */ }

let _cache = null, _at = 0;
const TTL = 5 * 60 * 1000; // 5 min; invalidate() forces a rebuild immediately

function tokenize(s) {
  return String(s == null ? '' : s).toLowerCase().replace(/[^a-z0-9]+/g, ' ').split(' ').filter(Boolean);
}

// light synonym expansion so "films"/"movie"/"streaming" etc. map onto catalog words
const SYN = {
  iptv: ['iptv', 'tv', 'channels', 'live', 'ott'],
  vpn: ['vpn', 'proxy', 'privacy'],
  movie: ['movie', 'movies', 'film', 'films', 'streaming', 'stream'],
  player: ['player', 'activation', 'device', 'mac'],
  ai: ['ai', 'gpt', 'gemini', 'assistant'],
  design: ['design', 'editing', 'editor', 'graphics', 'creative'],
  study: ['study', 'course', 'courses', 'learning', 'education', 'learn']
};
function expand(tokens) {
  const out = new Set(tokens);
  for (const t of tokens) for (const k of Object.keys(SYN)) if (SYN[k].indexOf(t) >= 0) SYN[k].forEach(x => out.add(x));
  return [...out];
}

async function build(pool) {
  const cats = (await pool.query('SELECT id, name, slug, tag FROM categories ORDER BY sort, id')).rows;
  const catById = {}; cats.forEach(c => { catById[c.id] = c; });

  const prods = (await pool.query(
    `SELECT id, slug, name, short_desc, long_desc, warranty, geo_note, note, category_id,
            most_selling, trending, offer_label
     FROM products WHERE active AND NOT hidden ORDER BY sort, id`)).rows;

  const planRows = (await pool.query(
    `SELECT product_id, label, price_pkr, price_usd, source, duration_value, duration_unit,
            warranty, popular
     FROM product_plans ORDER BY product_id, sort, id`)).rows;
  const faqRows = (await pool.query('SELECT product_id, q, a FROM product_faqs ORDER BY product_id, sort, id')).rows;
  const dlRows = (await pool.query('SELECT product_id, label, url FROM product_downloads WHERE NOT COALESCE(hidden,false) ORDER BY product_id, sort, id')).rows;

  const plansBy = {}, faqsBy = {}, dlBy = {};
  planRows.forEach(r => { (plansBy[r.product_id] = plansBy[r.product_id] || []).push(r); });
  faqRows.forEach(r => { (faqsBy[r.product_id] = faqsBy[r.product_id] || []).push(r); });
  dlRows.forEach(r => { (dlBy[r.product_id] = dlBy[r.product_id] || []).push(r); });

  const products = prods.map(p => {
    const pl = plansBy[p.id] || [];
    const prices = pl.map(x => Number(x.price_pkr || 0)).filter(n => n > 0);
    const cat = catById[p.category_id] || null;
    const kw = new Set(expand([...tokenize(p.name), ...tokenize(cat && cat.name), ...tokenize(p.short_desc)]));
    return {
      id: p.id, name: p.name, slug: p.slug, url: '/product/' + p.slug,
      category: cat ? cat.name : null, cat_slug: cat ? cat.slug : null,
      short_desc: p.short_desc || '', long_desc: p.long_desc || '',
      warranty: p.warranty || '', geo_note: p.geo_note || '',
      most_selling: !!p.most_selling, trending: !!p.trending, offer_label: p.offer_label || '',
      plans: pl.map(x => ({
        label: x.label,
        price_pkr: Number(x.price_pkr || 0),
        price_usd: (x.price_usd != null ? Number(x.price_usd) : null),
        source: x.source || 'manual',
        duration: (x.duration_value ? (x.duration_value + ' ' + (x.duration_unit || '')).trim() : ''),
        warranty: x.warranty || '',
        popular: !!x.popular
      })),
      priceFrom: prices.length ? Math.min.apply(null, prices) : 0,
      priceTo: prices.length ? Math.max.apply(null, prices) : 0,
      faqs: (faqsBy[p.id] || []).map(f => ({ q: f.q, a: f.a })),
      downloads: (dlBy[p.id] || []).map(d => ({ label: d.label, url: d.url })),
      keywords: [...kw]
    };
  });

  // site settings (name, whatsapp, currency) — real, via the app's own loader when present
  let settings = {};
  try { if (storefront && storefront.loadSettings) settings = await storefront.loadSettings(pool) || {}; } catch (e) {}
  const site = {
    name: settings.site_name || 'Galaxy Subz × Zayron',
    wa_number: settings.wa_number || process.env.WA_NUMBER || '',
    currency: settings.currency || 'PKR',
    rating: settings.rating || null
  };

  return {
    builtAt: Date.now(),
    site,
    categories: cats.map(c => ({ name: c.name, slug: c.slug, tag: c.tag || '' })),
    products,
    counts: {
      products: products.length, plans: planRows.length,
      faqs: faqRows.length, downloads: dlRows.length, categories: cats.length
    }
  };
}

async function get(pool, opts) {
  opts = opts || {};
  if (!opts.force && _cache && (Date.now() - _at) < TTL) return _cache;
  _cache = await build(pool); _at = Date.now();
  return _cache;
}
function invalidate() { _cache = null; _at = 0; }

module.exports = { get, build, invalidate, tokenize, expand };
