'use strict';
/* lib/seo_gates.js — quality / duplicate / indexability gates.
 *
 * The safety valve of the whole engine. A programmatic page engine's one real
 * danger is mass-producing thin or near-identical "doorway" pages, which Google
 * penalises site-wide. Nothing here touches the live site; it only decides
 * whether a geo page is good enough and distinct enough to be indexed.
 *
 *   contentHash(text)                 -> stable SHA1 of normalised content (exact-dup key)
 *   simhash(text)                     -> 64-bit locality hash as BigInt (near-dup fingerprint)
 *   similarity(a,b)                   -> 0..100  (100 = identical) from two simhashes
 *   duplicateScore(sim, others[])     -> 0..100  worst similarity against existing pages
 *   qualityScore(page)                -> 0..100  content richness
 *   decideIndexing(input, opts)       -> { indexing:'INDEX'|'NOINDEX', reasons:[], quality, duplicate }
 *
 * Dependency-free (node crypto only). Pure + deterministic -> unit-testable.
 */
const crypto = require('crypto');

const DEFAULTS = {
  qualityMin: 55,        // below this -> NOINDEX (still reachable, just not indexed)
  duplicateMax: 82,      // at/above this similarity to an existing page -> NOINDEX
  minWords: 120,         // floor for a non-thin page
  minProducts: 2,        // a landing with <2 offers is weak
  shingle: 3             // word n-gram size for simhash
};

/* ----------------------------- normalise ----------------------------- */
function normalise(text) {
  return String(text == null ? '' : text)
    .toLowerCase()
    .replace(/<[^>]+>/g, ' ')            // strip any stray HTML
    .replace(/[^a-z0-9 -￿\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
function words(text) { const n = normalise(text); return n ? n.split(' ') : []; }

function contentHash(text) {
  return crypto.createHash('sha1').update(normalise(text)).digest('hex');
}

/* ------------------------------ simhash ------------------------------ */
// 64-bit simhash over word-shingles. Returns a BigInt. Empty text -> 0n.
function simhash(text, shingleSize) {
  const w = words(text);
  const k = shingleSize || DEFAULTS.shingle;
  if (!w.length) return 0n;
  const grams = [];
  if (w.length < k) grams.push(w.join(' '));
  else for (let i = 0; i + k <= w.length; i++) grams.push(w.slice(i, i + k).join(' '));
  const v = new Array(64).fill(0);
  const freq = {};
  for (const g of grams) freq[g] = (freq[g] || 0) + 1;
  for (const g in freq) {
    const h = gramHash64(g);
    const wgt = freq[g];
    for (let i = 0; i < 64; i++) {
      const bit = (h >> BigInt(i)) & 1n;
      v[i] += (bit === 1n ? wgt : -wgt);
    }
  }
  let out = 0n;
  for (let i = 0; i < 64; i++) if (v[i] > 0) out |= (1n << BigInt(i));
  return out;
}
function gramHash64(g) {
  const d = crypto.createHash('sha1').update(g).digest();   // 20 bytes
  let h = 0n;
  for (let i = 0; i < 8; i++) h = (h << 8n) | BigInt(d[i]);  // first 64 bits
  return h;
}
function hamming(a, b) {
  let x = a ^ b, c = 0;
  while (x) { x &= (x - 1n); c++; }
  return c;
}
// 0..100 similarity between two simhashes.
function similarity(a, b) {
  if (a === 0n && b === 0n) return 0;           // two empties aren't "duplicates", they're both invalid
  return Math.round(((64 - hamming(a, b)) / 64) * 100);
}
// Worst-case similarity of this page's simhash against an array of existing ones.
function duplicateScore(sh, others) {
  if (!sh || sh === 0n || !Array.isArray(others) || !others.length) return 0;
  let worst = 0;
  for (const o of others) {
    const ob = typeof o === 'bigint' ? o : BigInt(o);
    if (ob === 0n) continue;
    const s = similarity(sh, ob);
    if (s > worst) worst = s;
  }
  return worst;
}

/* --------------------------- quality score --------------------------- */
// page: { text, products[], faq[], intro, breadcrumbs[], uniqueTokens[] }
function qualityScore(page, opts) {
  page = page || {}; opts = Object.assign({}, DEFAULTS, opts || {});
  const wc = page.wordCount != null ? page.wordCount : words(page.text || '').length;
  const nProd = (page.products && page.products.length) || page.productCount || 0;
  const nFaq = (page.faq && page.faq.length) || page.faqCount || 0;
  const introLen = words(page.intro || '').length;
  const nCrumb = (page.breadcrumbs && page.breadcrumbs.length) || page.breadcrumbCount || 0;
  const localTokens = (page.uniqueTokens && page.uniqueTokens.length) || page.localTokenCount || 0;

  let s = 0;
  // Body length (max 30): full credit at ~400 words.
  s += Math.min(30, Math.round((wc / 400) * 30));
  // Offers (max 25): full credit at 6 products.
  s += Math.min(25, Math.round((nProd / 6) * 25));
  // Localised intro (max 15): full credit at 60 words.
  s += Math.min(15, Math.round((introLen / 60) * 15));
  // FAQ (max 12): full credit at 4 Q/A.
  s += Math.min(12, Math.round((nFaq / 4) * 12));
  // Breadcrumb/structure (max 8): full credit at 4 levels.
  s += Math.min(8, Math.round((nCrumb / 4) * 8));
  // Local distinctiveness (max 10): place-specific tokens that make it not a template clone.
  s += Math.min(10, Math.round((localTokens / 8) * 10));

  // Hard floors: a page under the thin thresholds is capped low regardless.
  if (wc < opts.minWords) s = Math.min(s, 40);
  if (nProd < opts.minProducts) s = Math.min(s, 45);

  return Math.max(0, Math.min(100, s));
}

/* --------------------------- the decision ---------------------------- */
/* input: {
 *   status,            // DRAFT|REVIEW|PUBLISHED|ARCHIVED
 *   manualOverride,    // bool
 *   indexingStatus,    // INDEX|NOINDEX|AUTO  (respected when manualOverride)
 *   quality,           // precomputed, or pass `page` and we compute
 *   duplicate,         // precomputed, or pass `simhash`+`existing[]`
 *   page, simhash, existing,
 *   locationIndexable, locationSeoEnabled
 * } */
function decideIndexing(input, opts) {
  input = input || {}; opts = Object.assign({}, DEFAULTS, opts || {});
  const reasons = [];

  const quality = input.quality != null ? input.quality
    : (input.page ? qualityScore(input.page, opts) : null);
  const duplicate = input.duplicate != null ? input.duplicate
    : (input.simhash != null ? duplicateScore(input.simhash, input.existing || []) : 0);

  // 1) Manual override always wins (but AUTO falls through to automatic logic).
  if (input.manualOverride && input.indexingStatus && input.indexingStatus !== 'AUTO') {
    reasons.push('manual_override:' + input.indexingStatus);
    return { indexing: input.indexingStatus, reasons, quality, duplicate };
  }
  // 2) Only PUBLISHED pages may be indexed.
  const st = (input.status || 'DRAFT').toUpperCase();
  if (st !== 'PUBLISHED') { reasons.push('not_published:' + st); return noindex(reasons, quality, duplicate); }
  // 3) Location opted out.
  if (input.locationSeoEnabled === false) { reasons.push('location_seo_disabled'); return noindex(reasons, quality, duplicate); }
  if (input.locationIndexable === false) { reasons.push('location_not_indexable'); return noindex(reasons, quality, duplicate); }
  // 4) Thin content.
  if (quality != null && quality < opts.qualityMin) { reasons.push('low_quality:' + quality + '<' + opts.qualityMin); return noindex(reasons, quality, duplicate); }
  // 5) Near-duplicate of an existing page.
  if (duplicate >= opts.duplicateMax) { reasons.push('near_duplicate:' + duplicate + '>=' + opts.duplicateMax); return noindex(reasons, quality, duplicate); }

  reasons.push('ok');
  return { indexing: 'INDEX', reasons, quality, duplicate };
}
function noindex(reasons, quality, duplicate) { return { indexing: 'NOINDEX', reasons, quality, duplicate }; }

module.exports = {
  contentHash, simhash, similarity, duplicateScore, qualityScore, decideIndexing,
  DEFAULTS, _normalise: normalise, _words: words, _hamming: hamming
};
