'use strict';
/* Live Support Bot — Knowledge Base engine (Stage 1).
   Self-contained: builds the bot's "brain" purely from the real site database — no external
   service, no API, no LLM. Catalog-first: products, plans, prices, stock-source, warranty,
   FAQs, downloads, categories, plus site settings. Cached in-memory with a short TTL and a
   manual invalidate() so it auto-refreshes and can be re-trained the instant the admin changes
   anything. Everything here is grounded in actual rows — nothing invented. */

let storefront = null; try { storefront = require('./storefront'); } catch (e) { /* settings optional */ }

let _cache = null, _at = 0;
const TTL = 2 * 60 * 1000; // 2 min auto-refresh; invalidate() forces a rebuild immediately

// fast content fingerprint so the engines re-index only when something actually changed
function fnv(str) { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = (h * 16777619) >>> 0; } return h.toString(36); }

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

  // signature over everything the bot/SEO care about — changes when any product/plan/price/FAQ/category changes
  const sig = fnv(JSON.stringify({
    p: products.map(p => [p.id, p.name, p.short_desc, p.long_desc, p.cat_slug,
      p.plans.map(x => [x.label, x.price_pkr, x.price_usd]), p.faqs.map(f => [f.q, f.a])]),
    c: cats.map(c => [c.slug, c.name])
  }));

  return {
    builtAt: Date.now(),
    sig,
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

// Intent example phrases (seed the semantic intent index; kept small and generic).
const INTENT_EXAMPLES = [
  ['price', 'how much does it cost'], ['price', 'what is the price'], ['price', 'is it expensive'],
  ['plans', 'what plans are available'], ['plans', 'what durations do you have'],
  ['delivery', 'how long until i get it'], ['delivery', 'when will it be delivered'], ['delivery', 'is it instant'],
  ['payment', 'how can i pay'], ['payment', 'what payment methods do you accept'], ['payment', 'do you accept easypaisa'],
  ['warranty', 'is there a warranty'], ['warranty', 'what if it stops working'], ['warranty', 'can i get a replacement'],
  ['stock', 'is it available'], ['stock', 'do you have it in stock'],
  ['recommend', 'suggest a good one'], ['recommend', 'which is best'], ['recommend', 'what do you recommend'],
  ['catalog', 'what do you sell'], ['catalog', 'what categories do you have'],
  ['order_status', 'where is my order'], ['order_status', 'track my order'],
  ['renew', 'i want to renew'], ['renew', 'extend my subscription'],
  ['trial', 'can i get a free trial'], ['trial', 'i want to try it first'],
  ['resend', 'resend my code'], ['resend', 'i did not get my login'],
  ['complaint', 'it is not working'], ['complaint', 'i have a problem'],
  ['human', 'i want to talk to a person'], ['human', 'connect me to support'],
  ['greeting', 'hello there'], ['offers', 'any discounts or deals']
].map(x => ({ intent: x[0], phrase: x[1] }));

// Build the corpus the semantic sidecar embeds: product texts, flattened FAQs, categories, intents.
function corpus(kb) {
  const products = kb.products.map(p => ({
    id: p.id, name: p.name, cat_slug: p.cat_slug,
    text: [p.name, p.category, p.short_desc, p.long_desc].filter(Boolean).join('. ').replace(/\s+/g, ' ').slice(0, 480)
  }));
  const faqs = [];
  kb.products.forEach(p => (p.faqs || []).forEach((f, i) => { if (f.q || f.a) faqs.push({ id: p.id * 1000 + i, productId: p.id, q: f.q || '', a: f.a || '' }); }));
  const categories = kb.categories.map(c => ({ slug: c.slug, name: c.name }));
  return { products, faqs, categories, intents: INTENT_EXAMPLES, sig: kb.sig };
}

module.exports = { get, build, invalidate, tokenize, expand, corpus };
