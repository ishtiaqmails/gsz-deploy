'use strict';
/* Live Support Bot — answer engine (Stage 2).
   Self-contained NLU-lite + grounded answer assembly. No external LLM/API. Given the
   knowledge base (supportkb), a customer message and optional context, it:
     - detects intent with scored keyword rules,
     - extracts the product(s) the message refers to (token overlap + fuzzy match),
     - finds the single best-matching real FAQ when one fits,
     - assembles an answer purely from real catalog/FAQ data (never invents facts),
     - falls back to a WhatsApp handoff when it isn't confident.
   Agentic intents (order status / resend / renew / trial / claim) are detected here and
   returned with needsAction flags for Stage 5 to fulfil against the logged-in customer. */

const kb = require('./supportkb');

/* ---------- helpers ---------- */
function toks(s) { return kb.tokenize(s); }
function uniq(a) { return [...new Set(a)]; }

function lev(a, b) {
  a = String(a); b = String(b);
  if (a === b) return 0;
  const m = a.length, n = b.length; if (!m) return n; if (!n) return m;
  let prev = new Array(n + 1), cur = new Array(n + 1);
  for (let j = 0; j <= n; j++) prev[j] = j;
  for (let i = 1; i <= m; i++) {
    cur[0] = i;
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      cur[j] = Math.min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
    }
    const t = prev; prev = cur; cur = t;
  }
  return prev[n];
}
function closeTok(a, b) { const d = lev(a, b); return d === 0 ? 1 : (d === 1 && Math.min(a.length, b.length) >= 4 ? 0.6 : 0); }

function money(pkr) {
  pkr = Math.round(Number(pkr) || 0);
  return 'Rs ' + pkr.toLocaleString('en-US');
}

/* ---------- product matching ----------
   A product is identified by its DISTINCTIVE name tokens (opplex, crave, nord), not by
   generic/category words (tv, iptv, vpn, premium) which many products share. Distinctive
   hits dominate; generic words are only a light tiebreak. No synonym expansion in matching
   (that over-matched: a "TV" in any description pulled in every IPTV synonym). */
const GENERIC = new Set(['tv', 'iptv', 'vpn', 'ott', 'premium', 'player', 'players', 'pro', 'plus',
  'the', 'and', 'for', 'month', 'months', 'year', 'years', 'day', 'days', 'access', 'portal', 'device',
  'activation', 'edu', 'invite', 'full', 'user', 'best', 'live', 'channels', 'channel', 'subscription',
  'account', 'premium', 'app', 'service', 'services', 'tools', 'tool', 'ai', '1', '3', '6', '12']);
function distinctive(p) { return uniq(toks(p.name)).filter(w => !GENERIC.has(w) && w.length >= 2); }

function scoreProduct(mset, p) {
  const dist = distinctive(p);
  let score = 0, hitDistinct = false;
  for (const dt of dist) {
    if (mset.has(dt)) { score += 5; hitDistinct = true; continue; }
    let bonus = 0;
    for (const mt of mset) {
      if (mt.length >= 3 && dt.length >= 3 && (dt.indexOf(mt) >= 0 || mt.indexOf(dt) >= 0)) bonus = Math.max(bonus, 4);
      else { const c = closeTok(mt, dt); if (c) bonus = Math.max(bonus, 3 * c); }
    }
    if (bonus) { score += bonus; if (bonus >= 3) hitDistinct = true; }
  }
  // light generic/category nudge (capped) — only a tiebreak, never enough to identify alone
  const kwset = new Set(p.keywords);
  let gen = 0; for (const mt of mset) if (GENERIC.has(mt) && kwset.has(mt)) gen++;
  score += Math.min(gen, 3) * 0.4;
  return { score, hitDistinct };
}
function findProducts(bk, message, limit) {
  const mset = new Set(toks(message));
  const ranked = bk.products.map(p => { const r = scoreProduct(mset, p); return { p, s: r.score, d: r.hitDistinct }; })
    .filter(x => x.d && x.s >= 4).sort((a, b) => b.s - a.s);
  return ranked.slice(0, limit || 4).map(x => x.p);
}

/* ---------- FAQ matching ---------- */
function scoreText(mtoks, text) {
  const tt = new Set(toks(text)); if (!tt.size) return 0;
  let hit = 0; for (const t of mtoks) if (tt.has(t)) hit++;
  return hit / Math.sqrt(tt.size);
}
function bestFaq(bk, message, productId) {
  const mtoks = uniq(toks(message)).filter(t => t.length > 2);
  if (!mtoks.length) return null;
  let best = null;
  for (const p of bk.products) {
    if (productId && p.id !== productId) continue;
    for (const f of (p.faqs || [])) {
      const s = scoreText(mtoks, f.q) * 1.0 + scoreText(mtoks, f.a) * 0.3;
      if (!best || s > best.s) best = { s, q: f.q, a: f.a, product: p };
    }
  }
  return (best && best.s >= 0.9) ? best : null;
}

/* ---------- intent ---------- */
const RULES = [
  ['human', /\b(human|agent|representative|real person|talk to (someone|a person)|customer (care|support)|contact)\b/i, 3],
  ['order_status', /\b(order\s*(status|id|number)?|track|where.*(order|package)|GSZ-?\d+)\b/i, 2.6],
  ['resend', /\b(resend|re-?send|send (it )?again|didn.?t (get|receive)|not received|where.*(code|link|login|credential))\b/i, 2.6],
  ['renew', /\b(renew|renewal|re-?new|extend|expiring|expired|expire|expiry)\b/i, 2.6],
  ['trial', /\b(trial|free trial|test it out|try (it|before))\b/i, 2.4],
  ['complaint', /\b(not working|does.?n.?t work|stopped working|no longer work|broken|dead|error|issue|problem|complain|frozen|buffering)\b/i, 2.4],
  ['price', /\b(price|cost|how much|rate|kitna|kitne|charges?|fee|per month)\b/i, 2],
  ['plans', /\b(plans?|durations?|months?|validity|packages?|how long)\b/i, 1.6],
  ['warranty', /\b(warrant(y|ies)|guarantee|replace(ment)?|refund|money ?back)\b/i, 2],
  ['delivery', /\b(deliver(y|ed)?|how (fast|long|quick)|instant|receive|activation time|how (do i|to) get)\b/i, 1.9],
  ['payment', /\b(pay(ment)?|easy ?paisa|jazz ?cash|bank transfer|how (do i|to) pay|which method)\b/i, 1.9],
  ['stock', /\b(in ?stock|avail\w*|do you have|got any|got it)\b/i, 1.6],
  ['recommend', /\b(recommend|suggest|best|cheapest|affordable|which (one|should|is best)|good for|top pick)\b/i, 1.8],
  ['offers', /\b(offers?|discounts?|coupons?|promos?|deals?|sales?|vouchers?)\b/i, 1.8],
  ['greeting', /^\s*(hi|hello+|hey+|salam|assalam[ou]?[ -]?alaikum|aoa|yo|good (morning|evening|afternoon))\b/i, 1.2],
  ['thanks', /\b(thanks|thank you|shukria|thankyou|thx|appreciate it)\b/i, 1.2],
  ['bye', /\b(bye|good ?bye|khuda ?hafiz|see ya|that.?s all)\b/i, 1.1]
];
function detectIntent(message) {
  let best = { intent: 'fallback', score: 0 };
  for (const [name, re, w] of RULES) { if (re.test(message)) { if (w > best.score) best = { intent: name, score: w }; } }
  return best;
}

/* ---------- answer assembly (all grounded in real data) ---------- */
function pcard(p) {
  return { name: p.name, url: p.url, category: p.category, priceFrom: p.priceFrom, priceTo: p.priceTo, plans: p.plans.length };
}
function planLines(p) {
  return p.plans.map(pl => {
    const d = pl.label || pl.duration || 'Plan';
    return '• ' + d + ' — ' + money(pl.price_pkr) + (pl.price_usd ? ' ($' + pl.price_usd + ')' : '');
  }).join('\n');
}
function waLink(site, text) {
  const n = String(site.wa_number || '').replace(/[^0-9]/g, '');
  return n ? ('https://wa.me/' + n + (text ? ('?text=' + encodeURIComponent(text)) : '')) : null;
}

function answer(bk, message, ctx) {
  ctx = ctx || {};
  const msg = String(message || '').trim();
  const out = { intent: 'fallback', text: '', products: [], suggestions: [], handoff: false, needsAction: null };
  if (!msg) { out.text = 'Hi! Ask me about any product, price, plan, delivery, or your order.'; out.intent = 'greeting'; return out; }

  const det = detectIntent(msg);
  const prods = findProducts(bk, msg);
  const p = prods[0] || null;
  out.intent = det.intent;

  // conversational
  if (det.intent === 'greeting' && !p) {
    out.text = 'Hey! 👋 Welcome to ' + bk.site.name + '. Ask me about any product — prices, plans, delivery time, or help with an order.';
    out.suggestions = bk.categories.slice(0, 4).map(c => c.name);
    return out;
  }
  if (det.intent === 'thanks') { out.text = 'You\'re welcome! Anything else I can help with?'; return out; }
  if (det.intent === 'bye') { out.text = 'Take care! We\'re here 24/7 whenever you need us. 💙'; return out; }

  // human handoff
  if (det.intent === 'human') {
    out.handoff = true;
    const wl = waLink(bk.site, 'Hi, I need help on ' + bk.site.name);
    out.text = wl ? 'Sure — you can reach a human on WhatsApp here: ' + wl : 'Sure — our team is here to help. Please use the WhatsApp button on the site.';
    return out;
  }

  // agentic intents (fulfilled in Stage 5 against the logged-in customer)
  if (['order_status', 'resend', 'renew', 'trial', 'complaint'].indexOf(det.intent) >= 0) {
    out.needsAction = det.intent;
    const m = (msg.match(/GSZ-?\d+/i) || [])[0];
    if (m) out.orderNo = m.toUpperCase().replace('GSZ', 'GSZ-').replace('--', '-');
    // graceful grounded text; Stage 5 replaces with the real action result
    const map = {
      order_status: 'I can check your order status. ',
      resend: 'I can resend your code or link. ',
      renew: 'I can help you renew. ',
      trial: 'I can start a free trial for you. ',
      complaint: 'Sorry to hear that — I can open a claim and get it sorted. '
    };
    out.text = map[det.intent] + (ctx.customer ? 'One moment…' : 'Please sign in to your account first, then ask me again — or tap “My Hub”.');
    return out;
  }

  // a strongly-matching real FAQ beats a generic templated answer
  const faq = bestFaq(bk, msg, p ? p.id : null);
  if (faq && (det.intent === 'fallback' || det.intent === 'delivery' || det.intent === 'warranty' || det.intent === 'payment')) {
    out.text = faq.a;
    if (faq.product) out.products = [pcard(faq.product)];
    return out;
  }

  // catalog intents
  if (p) {
    if (det.intent === 'price' || det.intent === 'plans') {
      out.text = p.name + (p.plans.length ? ' — starts from ' + money(p.priceFrom) + '.\n' + planLines(p) : ' — pricing is on its page.');
      out.products = [pcard(p)];
      return out;
    }
    if (det.intent === 'warranty') {
      const w = p.warranty || (p.plans.find(x => x.warranty) || {}).warranty || '';
      out.text = w ? (p.name + ' warranty: ' + w) : (p.name + '\'s warranty is shown on its product page — it varies by plan.');
      out.products = [pcard(p)];
      return out;
    }
    if (det.intent === 'stock') {
      out.text = p.name + ' is available. ' + (p.plans.length ? 'Plans from ' + money(p.priceFrom) + '. Live stock shows on the product page.' : '');
      out.products = [pcard(p)];
      return out;
    }
    if (det.intent === 'delivery') {
      out.text = p.name + ' is delivered fast once your payment is confirmed — the exact delivery for this product is shown on its page.';
      out.products = [pcard(p)];
      return out;
    }
    // product_info / fallback-with-product
    const bits = [p.name];
    if (p.short_desc) bits.push('— ' + p.short_desc);
    out.text = bits.join(' ') + (p.plans.length ? '\nFrom ' + money(p.priceFrom) + ' · ' + p.plans.length + ' plan' + (p.plans.length > 1 ? 's' : '') + '.' : '');
    out.products = prods.slice(0, 3).map(pcard);
    return out;
  }

  // recommend / category browse (no single product)
  if (det.intent === 'recommend' || det.intent === 'plans' || det.intent === 'price') {
    // match a category if named (singular/plural tolerant, raw tokens)
    const stem = w => w.replace(/s$/, '');
    const rawm = uniq(toks(msg)).map(stem);
    let cat = bk.categories.find(c => {
      const ctoks = uniq([...toks(c.name), ...toks(c.slug)]).map(stem).filter(w => w.length >= 3);
      return ctoks.some(ct => rawm.indexOf(ct) >= 0);
    });
    let pool = bk.products.slice();
    if (cat) pool = pool.filter(x => x.cat_slug === cat.slug);
    pool.sort((a, b) => (b.most_selling - a.most_selling) || (b.trending - a.trending) || (a.priceFrom - b.priceFrom));
    const picks = pool.slice(0, 4);
    if (picks.length) {
      out.intent = 'recommend';
      out.text = cat ? ('Top picks in ' + cat.name + ':') : 'Here are some popular picks:';
      out.products = picks.map(pcard);
      return out;
    }
  }

  // a catalog question that named a product we couldn't find — say so helpfully
  if (['price', 'plans', 'warranty', 'stock'].indexOf(det.intent) >= 0) {
    out.text = 'I couldn\'t find that exact product. Could you give the name as it appears on the site? Here are our categories to browse.';
    out.suggestions = bk.categories.slice(0, 4).map(c => c.name);
    return out;
  }

  if (det.intent === 'payment') {
    out.text = 'You can pay with the methods shown at checkout (local wallets & bank transfer). Add a product to cart and the available options appear on the payment step.';
    return out;
  }
  if (det.intent === 'delivery') {
    out.text = 'Most orders are delivered fast after payment is confirmed — the exact delivery for each product is on its page. Need help with a specific one?';
    out.suggestions = bk.categories.slice(0, 4).map(c => c.name);
    return out;
  }
  if (det.intent === 'offers') {
    out.text = 'Current offers show in the bar at the very top of the site — tap the coupon there to copy it. Want recommendations within a budget?';
    return out;
  }

  // fallback — unsure → suggestions + handoff
  out.handoff = true;
  out.text = 'I\'m not sure I caught that. I can help with product prices, plans, delivery, offers, or your order. You can also reach our team on WhatsApp.';
  out.suggestions = bk.categories.slice(0, 4).map(c => c.name);
  const wl = waLink(bk.site, 'Hi, I have a question');
  if (wl) out.wa = wl;
  return out;
}

module.exports = { answer, detectIntent, findProducts, bestFaq, money };
