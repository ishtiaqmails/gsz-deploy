'use strict';
/* lib/geo_content.js — geo page content assembler.
 *
 * Turns a resolved location + intent + catalog into a full, LOCATION-VARIED
 * content model the template renders. Its real job is to make each page
 * genuinely different (demonym, region, nearby cities, local languages,
 * local currency + payment rail, intent-specific copy & FAQ) so pages clear
 * the quality/duplicate gates instead of reading as doorway clones.
 *
 * Dependency-injected — NO direct DB/require, so it unit-tests offline and
 * wires to the real storefront + gsz_pricing in the route layer:
 *   deps = {
 *     catalog(ctx)            -> [ {id,name,slug,category,price,usd,available,...} ]
 *     price(product, cc, opts)-> { display, amount, currency, symbol, usd }   (wraps gsz_pricing.resolve)
 *     siblings(target, n)     -> [ {name,slug,url} ]   nearby same-type locations
 *     relatedCategories(ctx)  -> [ {name,slug,url} ]
 *     relatedIntents(ctx)     -> [ {name,slug,url} ]
 *     rules(target,opts)      -> geo_product_rules merged (from geo.recommendedRules)
 *   }
 *
 * CHECKOUT RULE encoded in copy: Pakistan settles in PKR via Meezan Bank +
 * NayaPay; everywhere else settles in USD via Binance. Display currency can be
 * the visitor's local currency, but the page is honest about settlement.
 */

const PAYMENT = {
  PK: { rail: 'local', currency: 'PKR', methods: ['Meezan Bank', 'NayaPay'], label: 'Meezan Bank or NayaPay (PKR)' },
  INTL: { rail: 'binance', currency: 'USD', methods: ['Binance'], label: 'Binance (USD)' }
};

function cap(s) { return String(s || '').replace(/\b\w/g, c => c.toUpperCase()); }
function uniq(a) { return Array.from(new Set(a.filter(Boolean))); }
function sentence(parts) { return parts.filter(Boolean).join(' ').replace(/\s{2,}/g, ' ').replace(/\s+([,.])/g, '$1').trim(); }

// Resolve the locale/payment profile from the inheritance chain.
function localeProfile(ctx) {
  const country = ctx.country || {};
  const chain = ctx.chain || [];
  const cc = (country.country_code || country.iso_code || '').toUpperCase();
  const inherit = (field) => {
    for (const r of chain) { if (r && r[field] != null && r[field] !== '') return r[field]; }
    return null;
  };
  const languages = (function () {
    for (const r of chain) if (r && Array.isArray(r.languages) && r.languages.length) return r.languages;
    return ['en'];
  })();
  const pay = cc === 'PK' ? PAYMENT.PK : PAYMENT.INTL;
  return {
    countryCode: cc,
    currency: inherit('currency') || pay.currency,
    currencySymbol: inherit('currency_symbol') || (pay.currency === 'PKR' ? 'Rs ' : '$'),
    languages,
    demonym: inherit('demonym') || (ctx.target && ctx.target.demonym) || '',
    paymentRail: pay.rail,
    paymentMethods: pay.methods,
    paymentLabel: pay.label,
    checkoutCurrency: pay.currency
  };
}

function buildBreadcrumbs(ctx) {
  const cat = ctx.categorySlug ? { name: ctx.categoryName || cap(ctx.categorySlug), url: '/category/' + ctx.categorySlug } : null;
  const crumbs = [{ name: 'Home', url: '/' }];
  if (cat) crumbs.push(cat);
  const seg = [ctx.categorySlug];
  const add = (loc) => { if (!loc) return; seg.push(loc.slug); crumbs.push({ name: loc.name, url: '/' + seg.filter(Boolean).join('/') }); };
  add(ctx.country); add(ctx.region); add(ctx.city);
  if (ctx.intent && ctx.intent.slug) crumbs.push({ name: ctx.intent.name, url: ctx.path });
  return crumbs;
}

function buildHeadline(ctx, L) {
  const where = ctx.target ? ctx.target.name : (ctx.country && ctx.country.name) || '';
  const cat = ctx.categoryName || 'Digital Subscriptions';
  const key = (ctx.intent && ctx.intent.key) || 'BEST';
  const map = {
    BEST: `Best ${cat} in ${where}`,
    BUY: `Buy ${cat} in ${where}`,
    PRICE: `${cat} Prices in ${where}`,
    TRIAL: `${cat} Free Trial in ${where}`,
    COMPARE: `Compare ${cat} Plans in ${where}`,
    REVIEW: `${cat} Reviews in ${where}`,
    LOCAL: `${cat} in ${where}`,
    CHANNELS: `${cat} Channels in ${where}`,
    SPORTS: `${cat} Sports Packages in ${where}`,
    AVAILABILITY: `Is ${cat} Available in ${where}?`,
    HOW_TO: `How to Get ${cat} in ${where}`,
    PROBLEM_SOLUTION: `${cat} Not Working in ${where}? Here's the Fix`
  };
  return map[key] || `${cat} in ${where}`;
}

// Two short, location-specific paragraphs — the main dup-beating variation.
function buildIntro(ctx, L, products) {
  const where = ctx.target ? ctx.target.name : (ctx.country && ctx.country.name) || '';
  const cat = ctx.categoryName || 'digital subscriptions';
  const demo = L.demonym ? (L.demonym + ' ') : '';
  const region = ctx.region ? ctx.region.name : '';
  const country = ctx.country ? ctx.country.name : '';
  const n = products ? products.length : 0;
  const langLine = (L.languages && L.languages.length > 1)
    ? `Content is available in ${L.languages.slice(0, 3).map(l => LANG[l] || l.toUpperCase()).join(', ')}.` : '';

  const place = ctx.city ? `${where}${region ? ', ' + region : ''}` : where;
  const brand = ctx.siteName || 'Galaxy Subz × Zayron';
  const p1 = sentence([
    `${brand} delivers ${cat} to ${demo}customers across ${place}${(country && country !== where) ? ' and the rest of ' + country : ''}.`,
    n ? `Choose from ${n} ${n === 1 ? 'plan' : 'plans'} with instant digital delivery — your login details arrive within minutes of payment, 24/7.` :
        `Every plan is delivered digitally within minutes of payment, any time of day.`
  ]);
  const p2 = sentence([
    L.paymentRail === 'local'
      ? `Pay the easy way in ${where}: ${L.paymentLabel}. Prices are shown in Pakistani Rupees, with no card or currency hassle.`
      : `Pay securely from ${where} with ${L.paymentLabel}. Prices are shown in ${L.currency}; checkout settles in USD via Binance so there are no local-bank blocks.`,
    langLine,
    `Need help choosing? Our support team answers ${demo ? demo + '' : ''}questions before and after you buy.`
  ]);
  return [p1, p2];
}

const LANG = { en: 'English', ur: 'Urdu', ps: 'Pashto', ar: 'Arabic', hi: 'Hindi', pa: 'Punjabi', sd: 'Sindhi', fa: 'Persian', fr: 'French', es: 'Spanish' };

// Intent- and location-varied FAQ (feeds FAQPage schema + on-page content).
function buildFaq(ctx, L, products) {
  const where = ctx.target ? ctx.target.name : (ctx.country && ctx.country.name) || '';
  const cat = ctx.categoryName || 'subscriptions';
  const faq = [];
  faq.push({
    q: `How do I pay for ${cat} in ${where}?`,
    a: L.paymentRail === 'local'
      ? `In ${where} you can pay with ${L.paymentMethods.join(' or ')} in Pakistani Rupees. After payment your access details are delivered within minutes.`
      : `From ${where} you pay with ${L.paymentMethods.join(' or ')} in USD. Prices are displayed in ${L.currency} for convenience and settle in USD at checkout.`
  });
  faq.push({
    q: `How fast is delivery in ${where}?`,
    a: `Delivery is instant and automated — most ${where} orders are completed within a few minutes, any time of day or night.`
  });
  if (products && products.length) {
    const cheapest = products.reduce((m, p) => (p._price && (!m || Number(p._price.amount) < Number(m._price.amount)) ? p : m), null);
    if (cheapest && cheapest._price) {
      faq.push({
        q: `How much does ${cat} cost in ${where}?`,
        a: `Plans in ${where} start from ${cheapest._price.display}. You can see every plan and its live local price on this page before you order.`
      });
    }
  }
  const key = (ctx.intent && ctx.intent.key) || '';
  if (key === 'TRIAL') faq.push({ q: `Is there a free trial in ${where}?`, a: `Selected plans include a trial. Where a trial is offered it is shown on the plan itself; otherwise our shortest paid plan lets you test the service at low cost.` });
  if (key === 'SPORTS') faq.push({ q: `Can I watch live sports in ${where}?`, a: `Yes — our packages carry major live sports and event channels available to ${where} viewers, subject to the plan you choose.` });
  faq.push({
    q: `Do you support customers in ${where}?`,
    a: `Yes. We serve ${where} with local pricing, ${L.paymentLabel}, and 24/7 support before and after purchase.`
  });
  return faq;
}

function buildInternalLinks(ctx, sib, cats, intents) {
  const links = [];
  if (ctx.city && ctx.country) links.push({ name: `${ctx.categoryName || 'All'} in ${ctx.country.name}`, url: '/' + [ctx.categorySlug, ctx.country.slug].join('/') });
  if (ctx.region && ctx.country && !ctx.city) links.push({ name: `${ctx.categoryName || 'All'} in ${ctx.country.name}`, url: '/' + [ctx.categorySlug, ctx.country.slug].join('/') });
  (sib || []).slice(0, 6).forEach(s => links.push(s));
  (cats || []).slice(0, 4).forEach(c => links.push(c));
  (intents || []).slice(0, 4).forEach(i => links.push(i));
  // de-dupe by url
  const seen = new Set(); return links.filter(l => l && l.url && !seen.has(l.url) && seen.add(l.url));
}

// Distinct, place-specific tokens — fed to the quality gate as uniqueTokens.
function localTokens(ctx, L) {
  const t = [];
  if (ctx.target) t.push(ctx.target.name);
  if (ctx.region) t.push(ctx.region.name);
  if (ctx.country) t.push(ctx.country.name);
  if (L.demonym) t.push(L.demonym);
  (L.languages || []).forEach(l => t.push(LANG[l] || l));
  (L.paymentMethods || []).forEach(m => t.push(m));
  t.push(L.currency);
  return uniq(t.map(x => String(x).toLowerCase()));
}

/* -------------------------------- assemble ------------------------------- */
async function assemble(ctx, deps) {
  ctx = ctx || {}; deps = deps || {};
  const L = localeProfile(ctx);

  // 1) catalog for this category/location, with geo rules applied + local pricing
  let products = [];
  if (typeof deps.catalog === 'function') {
    products = (await deps.catalog(ctx)) || [];
  }
  const rules = (typeof deps.rules === 'function') ? (await deps.rules(ctx.target, { categoryId: ctx.categoryId }) || []) : [];
  const ruleBy = {}; rules.forEach(r => { if (r.product_id != null) ruleBy['p' + r.product_id] = r; });

  // apply rules (availability/featured/recommended/regional price/notice) + resolve local price
  const out = [];
  for (const p of products) {
    const r = ruleBy['p' + (p.id)] || null;
    if (r && r.availability === 'unavailable') continue;              // hidden where unavailable
    const item = Object.assign({}, p);
    item.recommended = !!(r && r.recommended) || !!p.recommended;
    item.featured = !!(r && r.featured) || !!p.featured;
    if (r && r.special_notice) item.notice = r.special_notice;
    if (r && r.vpn_required) item.vpnRequired = true;
    item.url = p.url || ('/product/' + (p.slug || p.id));
    if (typeof deps.price === 'function') {
      try { item._price = await deps.price(p, L.countryCode, { regional: r && r.regional_price }); } catch (e) { item._price = null; }
    }
    out.push(item);
  }
  // recommended/featured first, then given order
  out.sort((a, b) => (Number(b.featured) - Number(a.featured)) || (Number(b.recommended) - Number(a.recommended)));

  const breadcrumbs = buildBreadcrumbs(ctx);
  const h1 = buildHeadline(ctx, L);
  const intro = buildIntro(ctx, L, out);
  const faq = buildFaq(ctx, L, out);
  const sib = (typeof deps.siblings === 'function') ? (await deps.siblings(ctx.target, 6) || []) : [];
  const cats = (typeof deps.relatedCategories === 'function') ? (await deps.relatedCategories(ctx) || []) : [];
  const intents = (typeof deps.relatedIntents === 'function') ? (await deps.relatedIntents(ctx) || []) : [];
  const internalLinks = buildInternalLinks(ctx, sib, cats, intents);
  const uniqueTokens = localTokens(ctx, L);

  // flat text for the quality/duplicate gates
  const text = [h1, intro.join(' '), faq.map(f => f.q + ' ' + f.a).join(' '),
    out.map(p => p.name).join(' ')].join(' ');

  return {
    locale: L, breadcrumbs, h1, intro, faq, internalLinks, uniqueTokens,
    products: out, text,
    // ready-made inputs for the gates + meta builders
    gateInput: { text, intro: intro.join(' '), products: out, faq, breadcrumbs, uniqueTokens },
    metaProducts: out.map(p => ({
      name: p.name, url: p.url, available: p.available !== false,
      price: p._price ? p._price.amount : (p.price != null ? p.price : null),
      priceUsd: p._price ? p._price.usd : (p.usd != null ? p.usd : null),
      currency: p._price ? p._price.currency : null, description: p.description || p.tagline
    }))
  };
}

module.exports = {
  assemble, localeProfile, buildBreadcrumbs, buildHeadline, buildIntro, buildFaq,
  buildInternalLinks, localTokens, PAYMENT, LANG
};
