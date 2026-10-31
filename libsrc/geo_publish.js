'use strict';
/* lib/geo_publish.js — the publish/unpublish engine for geo pages.
 *
 * This is the shell-independent core the admin "Publish" button calls. It:
 *   1. rebuilds the page's gate text from content_data,
 *   2. scores quality + duplicate vs other PUBLISHED pages,
 *   3. decides INDEX / NOINDEX via seo_gates (respecting manual_override),
 *   4. flips status -> PUBLISHED and writes indexing_status + scores,
 *   5. if INDEX, pings the EXISTING lib/indexnow (ping) so Bing/Yandex pick it up
 *      — a safe no-op until an IndexNow key is configured.
 *
 * unpublish() archives a page. recomputeAll() re-evaluates every published page's
 * indexing (e.g. after content changes). Fail-safe: indexnow errors never block a
 * publish. Pure-ish (pool injected); testable with a mock pool + injected pinger.
 */
const path = require('path');
const gates = require('./seo_gates');

const SITE_URL = (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '');

function reconstructText(cd) {
  cd = cd || {};
  const parts = [];
  if (cd.h1) parts.push(cd.h1);
  if (Array.isArray(cd.intro)) parts.push(cd.intro.join(' '));
  if (Array.isArray(cd.faq)) parts.push(cd.faq.map(f => (f.q || '') + ' ' + (f.a || '')).join(' '));
  if (Array.isArray(cd.products)) parts.push(cd.products.map(p => p.name).join(' '));
  return parts.join(' ');
}
function gateInputFrom(cd) {
  cd = cd || {};
  return {
    text: reconstructText(cd),
    intro: Array.isArray(cd.intro) ? cd.intro.join(' ') : (cd.intro || ''),
    products: cd.products || [],
    faq: cd.faq || [],
    breadcrumbs: cd.breadcrumbs || [],
    uniqueTokens: cd.uniqueTokens || []
  };
}

async function publishedSimhashes(pool, excludeId) {
  const rows = (await pool.query(
    "SELECT id, content_data FROM geo_pages WHERE status='PUBLISHED' AND indexing_status <> 'NOINDEX'" +
    (excludeId ? ' AND id <> $1' : ''), excludeId ? [excludeId] : [])).rows;
  return rows.map(r => gates.simhash(reconstructText(r.content_data || {}))).filter(Boolean);
}

function lazyIndexnow() {
  try { return require(path.join(__dirname, 'indexnow')); } catch (e) { return null; }
}

// publish(pool, idOrSlug, { pinger?, base?, force? }) -> { ok, slug, indexing, quality, duplicate, pinged, reasons }
async function publish(pool, idOrSlug, opts) {
  opts = opts || {};
  const page = await loadPage(pool, idOrSlug);
  if (!page) return { ok: false, error: 'not_found' };

  const cd = page.content_data || {};
  const gi = gateInputFrom(cd);
  const quality = (page.quality_score != null && !opts.recompute) ? page.quality_score : gates.qualityScore(gi);
  const sh = gates.simhash(gi.text);
  const others = await publishedSimhashes(pool, page.id);
  const duplicate = gates.duplicateScore(sh, others);

  const decision = gates.decideIndexing({
    status: 'PUBLISHED',
    manualOverride: page.manual_override,
    indexingStatus: page.indexing_status,
    quality, duplicate,
    locationIndexable: opts.locationIndexable, locationSeoEnabled: opts.locationSeoEnabled
  });

  await pool.query(
    "UPDATE geo_pages SET status='PUBLISHED', indexing_status=$2, quality_score=$3, duplicate_score=$4, published_at=COALESCE(published_at, now()), updated_at=now() WHERE id=$1",
    [page.id, decision.indexing, quality, duplicate]);

  // IndexNow ping only when actually indexable (safe no-op without a key)
  let pinged = false;
  if (decision.indexing === 'INDEX') {
    const url = SITE_URL + page.slug;
    try {
      const pinger = opts.pinger || (function () { const i = lazyIndexnow(); return i && i.ping ? (urls) => i.ping(pool, SITE_URL, urls) : null; })();
      if (pinger) { const r = await pinger([url]); pinged = !!(r && (r.status === 200 || r.status === 202 || r.submitted)); }
    } catch (e) { /* never block publish on ping */ }
  }

  return { ok: true, id: page.id, slug: page.slug, indexing: decision.indexing, quality, duplicate, pinged, reasons: decision.reasons };
}

async function unpublish(pool, idOrSlug, opts) {
  opts = opts || {};
  const page = await loadPage(pool, idOrSlug);
  if (!page) return { ok: false, error: 'not_found' };
  const to = (opts.to === 'draft') ? 'DRAFT' : 'ARCHIVED';
  await pool.query("UPDATE geo_pages SET status=$2, updated_at=now() WHERE id=$1", [page.id, to]);
  return { ok: true, id: page.id, slug: page.slug, status: to };
}

// Re-evaluate indexing for every PUBLISHED page (after bulk content changes).
async function recomputeAll(pool) {
  const rows = (await pool.query("SELECT id, slug, content_data, quality_score, manual_override, indexing_status FROM geo_pages WHERE status='PUBLISHED' ORDER BY id")).rows;
  // simhash each once
  const sims = rows.map(r => ({ id: r.id, sh: gates.simhash(reconstructText(r.content_data || {})) }));
  let changed = 0;
  for (const r of rows) {
    const gi = gateInputFrom(r.content_data || {});
    const quality = r.quality_score != null ? r.quality_score : gates.qualityScore(gi);
    const my = sims.find(s => s.id === r.id);
    const others = sims.filter(s => s.id !== r.id).map(s => s.sh).filter(Boolean);
    const duplicate = gates.duplicateScore(my ? my.sh : 0n, others);
    const d = gates.decideIndexing({ status: 'PUBLISHED', manualOverride: r.manual_override, indexingStatus: r.indexing_status, quality, duplicate });
    if (d.indexing !== r.indexing_status) {
      await pool.query("UPDATE geo_pages SET indexing_status=$2, duplicate_score=$3, updated_at=now() WHERE id=$1", [r.id, d.indexing, duplicate]);
      changed++;
    }
  }
  return { evaluated: rows.length, changed };
}

async function loadPage(pool, idOrSlug) {
  const byId = /^\d+$/.test(String(idOrSlug));
  const r = await pool.query(
    'SELECT * FROM geo_pages WHERE ' + (byId ? 'id=$1' : 'lower(slug)=lower($1)') + ' LIMIT 1', [idOrSlug]);
  return r.rows[0] || null;
}

module.exports = { publish, unpublish, recomputeAll, reconstructText, gateInputFrom, publishedSimhashes };
