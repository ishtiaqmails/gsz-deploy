'use strict';
/* lib/seo_engine.js — Galaxy Search Intelligence core.
 *
 * The self-running brain: it keeps a registry of every URL, inspects pages for
 * SEO health, records + auto-resolves issues, scores each URL, and closes the
 * publish -> sitemap-dirty -> IndexNow loop. It is deliberately BOUNDED so it can
 * never compete with real customer traffic:
 *   - concurrency cap (default 2)
 *   - max URLs per sweep (default 40)
 *   - delay between fetches
 *   - allowCrawl() guard hook the host wires to peak-hour / load checks
 *   - fetch has a timeout + byte cap + bounded redirects
 *
 * Layering (pure first, networked last):
 *   normalizeUrl(u,base)            pure   canonical key for the registry
 *   inspectHtml(html,{url,base})    pure   title/meta/canonical/h1/schema/links/alt + issues
 *   scoreFromInspection(insp)       pure   technical/content/schema/link/health 0..100
 *   diffIssues(existing,found)      pure   {toOpen, toResolve, toKeep}
 *   registerUrl / recordIssues / applyScores        DB
 *   onPublish(pool,evt)             loop   register + sitemap-dirty + queue IndexNow
 *   sweep(pool,opts)                loop   bounded fetch+inspect+score+issue pass
 *   events: on()/emit()            tiny in-process bus
 *
 * Dependency-free (node https + crypto). Everything networked is injectable.
 */
const https = require('https');
const http = require('http');
const crypto = require('crypto');
const { URL } = require('url');

/* ------------------------------ events ------------------------------ */
function makeBus() {
  const map = {};
  return {
    on(ev, fn) { (map[ev] = map[ev] || []).push(fn); return this; },
    async emit(ev, payload) {
      const fns = map[ev] || [];
      const out = [];
      for (const fn of fns) { try { out.push(await fn(payload)); } catch (e) { out.push({ error: String(e && e.message || e) }); } }
      return out;
    },
    _map: map
  };
}

/* --------------------------- url normalise --------------------------- */
const TRACKING = /^(utm_|fbclid$|gclid$|mc_|ref$|ref_src$|igshid$|_hs|vero_)/i;
function normalizeUrl(u, base) {
  if (!u) return null;
  let url;
  try { url = new URL(u, base); } catch (e) { return null; }
  if (!/^https?:$/.test(url.protocol)) return null;
  url.hash = '';
  url.hostname = url.hostname.toLowerCase();
  // drop tracking params, keep the rest sorted for a stable key
  const keep = [];
  for (const [k, v] of url.searchParams.entries()) if (!TRACKING.test(k)) keep.push([k, v]);
  keep.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0);
  url.search = '';
  for (const [k, v] of keep) url.searchParams.append(k, v);
  let out = url.toString();
  // strip a trailing slash on non-root paths
  out = out.replace(/\/(\?|$)/, (m, g) => (url.pathname === '/' ? m : (g || '')));
  if (url.pathname !== '/' && url.pathname.endsWith('/') && !url.search) out = out.replace(/\/+$/, '');
  return out;
}

/* ----------------------------- inspector ----------------------------- */
// Regex-based signal extraction — robust to malformed HTML, no DOM dependency.
function attrOf(tag, name) {
  const m = tag.match(new RegExp(name + '\\s*=\\s*("([^"]*)"|\'([^\']*)\'|([^\\s>]+))', 'i'));
  return m ? (m[2] != null ? m[2] : m[3] != null ? m[3] : m[4] || '') : null;
}
function metaByName(html, which, name) {
  const re = /<meta\b[^>]*>/gi; let m;
  while ((m = re.exec(html))) {
    const tag = m[0];
    const v = attrOf(tag, which);
    if (v && v.toLowerCase() === name.toLowerCase()) return attrOf(tag, 'content') || '';
  }
  return null;
}
function stripToText(html) {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&[a-z#0-9]+;/gi, ' ')
    .replace(/\s+/g, ' ').trim();
}

// Returns { signals, issues } — issues: [{code,severity,auto_fixable,evidence}]
function inspectHtml(html, ctx) {
  ctx = ctx || {}; html = String(html || '');
  const url = ctx.url || '';
  const base = ctx.base || url;
  const S = {};

  const titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  S.title = titleM ? titleM[1].replace(/\s+/g, ' ').trim() : '';
  S.titleLen = S.title.length;
  S.description = metaByName(html, 'name', 'description') || '';
  S.descLen = S.description.length;
  S.robots = (metaByName(html, 'name', 'robots') || '').toLowerCase();

  const canM = html.match(/<link\b[^>]*rel\s*=\s*["']?canonical["']?[^>]*>/i);
  S.canonical = canM ? (attrOf(canM[0], 'href') || '') : '';

  S.h1Count = (html.match(/<h1\b[^>]*>/gi) || []).length;
  S.jsonLd = (html.match(/<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>/gi) || []).length;
  S.ogCount = (html.match(/<meta\b[^>]*property\s*=\s*["']og:/gi) || []).length;

  // images without alt
  const imgs = html.match(/<img\b[^>]*>/gi) || [];
  S.imgCount = imgs.length;
  S.imgNoAlt = imgs.filter(t => { const a = attrOf(t, 'alt'); return a == null; }).length;

  // links (internal vs external)
  const links = []; const re = /<a\b[^>]*href\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))[^>]*>/gi; let m;
  while ((m = re.exec(html))) {
    const href = (m[2] != null ? m[2] : m[3] != null ? m[3] : m[4] || '').trim();
    if (!href || /^(#|mailto:|tel:|javascript:)/i.test(href)) continue;
    const norm = normalizeUrl(href, base);
    if (!norm) continue;
    let internal = false;
    try { internal = new URL(norm).host === new URL(base).host; } catch (e) {}
    links.push({ href: norm, anchor: stripToText(m[0]).slice(0, 120), internal });
  }
  S.links = links;
  S.internalLinks = links.filter(l => l.internal).length;
  S.externalLinks = links.length - S.internalLinks;

  const text = stripToText(html);
  S.wordCount = text ? text.split(' ').length : 0;
  S.contentHash = crypto.createHash('sha1').update(text.toLowerCase()).digest('hex');

  // ---- issues ----
  const issues = [];
  const add = (code, severity, auto_fixable, evidence) => issues.push({ code, severity, auto_fixable: !!auto_fixable, evidence: evidence || {} });
  if (!S.title) add('MISSING_TITLE', 'CRITICAL', false);
  else if (S.titleLen > 65) add('TITLE_TOO_LONG', 'WARNING', true, { len: S.titleLen });
  else if (S.titleLen < 15) add('TITLE_TOO_SHORT', 'WARNING', false, { len: S.titleLen });
  if (!S.description) add('MISSING_META_DESCRIPTION', 'HIGH', true);
  else if (S.descLen > 165) add('META_DESCRIPTION_TOO_LONG', 'INFO', true, { len: S.descLen });
  if (!S.canonical) add('MISSING_CANONICAL', 'HIGH', true);
  else if (ctx.expectedCanonical && normalizeUrl(S.canonical, base) !== normalizeUrl(ctx.expectedCanonical, base))
    add('CANONICAL_MISMATCH', 'HIGH', true, { found: S.canonical, expected: ctx.expectedCanonical });
  if (S.h1Count === 0) add('MISSING_H1', 'WARNING', false);
  else if (S.h1Count > 1) add('MULTIPLE_H1', 'INFO', false, { count: S.h1Count });
  if (S.jsonLd === 0) add('MISSING_STRUCTURED_DATA', 'WARNING', true);
  if (S.imgNoAlt > 0) add('IMG_MISSING_ALT', 'INFO', false, { count: S.imgNoAlt });
  if (S.wordCount < 120) add('THIN_CONTENT', 'HIGH', false, { words: S.wordCount });
  if (S.internalLinks === 0) add('NO_INTERNAL_LINKS', 'WARNING', true);
  if (/noindex/.test(S.robots)) add('META_NOINDEX', 'INFO', false, { robots: S.robots });

  return { signals: S, issues };
}

/* ------------------------------ scoring ------------------------------ */
function scoreFromInspection(insp) {
  const S = (insp && insp.signals) || {};
  const issues = (insp && insp.issues) || [];
  const has = code => issues.some(i => i.code === code);

  let tech = 100;
  if (has('MISSING_CANONICAL')) tech -= 20;
  if (has('CANONICAL_MISMATCH')) tech -= 15;
  if (has('META_NOINDEX')) tech -= 10;
  if (has('MISSING_TITLE')) tech -= 25;
  if (has('TITLE_TOO_LONG') || has('TITLE_TOO_SHORT')) tech -= 5;

  let content = 100;
  if (has('THIN_CONTENT')) content -= 40;
  else content = Math.min(100, Math.round((S.wordCount || 0) / 500 * 100));
  if (has('MISSING_META_DESCRIPTION')) content -= 10;
  if (has('MISSING_H1')) content -= 10;

  let schema = has('MISSING_STRUCTURED_DATA') ? 30 : Math.min(100, 60 + (S.jsonLd || 0) * 20);
  let link = Math.min(100, (S.internalLinks || 0) * 12 + (S.externalLinks ? 10 : 0));
  if (has('NO_INTERNAL_LINKS')) link = Math.min(link, 20);

  const clamp = n => Math.max(0, Math.min(100, Math.round(n)));
  tech = clamp(tech); content = clamp(content); schema = clamp(schema); link = clamp(link);
  const health = clamp(tech * 0.35 + content * 0.35 + schema * 0.15 + link * 0.15);
  return { technical_score: tech, content_score: content, schema_score: schema, link_score: link, health_score: health };
}

/* --------------------------- issue diffing --------------------------- */
// existing: rows from seo_issues (OPEN). found: inspectHtml().issues.
function diffIssues(existing, found) {
  existing = existing || []; found = found || [];
  const foundCodes = new Set(found.map(f => f.code));
  const existByCode = {}; existing.forEach(e => { existByCode[e.code] = e; });
  const toOpen = found.filter(f => !existByCode[f.code]);
  const toResolve = existing.filter(e => !foundCodes.has(e.code));
  const toKeep = found.filter(f => existByCode[f.code]);
  return { toOpen, toResolve, toKeep };
}

/* ------------------------------- DB ---------------------------------- */
async function registerUrl(pool, u) {
  const norm = normalizeUrl(u.url, u.base);
  if (!norm) return null;
  const r = await pool.query(
    `INSERT INTO seo_urls(url,normalized_url,entity_type,entity_id,canonical_url,indexable,crawl_priority,lifecycle_state,content_hash,last_changed_at,updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,COALESCE($8,'DISCOVERED'),$9,now(),now())
     ON CONFLICT (normalized_url) DO UPDATE SET
       entity_type=COALESCE(EXCLUDED.entity_type,seo_urls.entity_type),
       entity_id=COALESCE(EXCLUDED.entity_id,seo_urls.entity_id),
       canonical_url=COALESCE(EXCLUDED.canonical_url,seo_urls.canonical_url),
       indexable=COALESCE(EXCLUDED.indexable,seo_urls.indexable),
       crawl_priority=COALESCE(EXCLUDED.crawl_priority,seo_urls.crawl_priority),
       last_changed_at=CASE WHEN seo_urls.content_hash IS DISTINCT FROM EXCLUDED.content_hash THEN now() ELSE seo_urls.last_changed_at END,
       content_hash=COALESCE(EXCLUDED.content_hash,seo_urls.content_hash),
       updated_at=now()
     RETURNING id,normalized_url`,
    [norm, norm, u.entityType || null, u.entityId || null, u.canonical || null,
     u.indexable == null ? null : !!u.indexable, u.priority == null ? null : u.priority,
     u.lifecycle || null, u.contentHash || null]);
  return r.rows[0];
}

async function recordIssues(pool, urlId, url, found) {
  const ex = (await pool.query("SELECT id,code FROM seo_issues WHERE url_id=$1 AND status IN ('OPEN','AUTO_FIXING','MANUAL_REVIEW','RECURRING')", [urlId])).rows;
  const { toOpen, toResolve, toKeep } = diffIssues(ex, found);
  for (const f of toOpen) {
    await pool.query(
      "INSERT INTO seo_issues(url_id,url,code,severity,auto_fixable,evidence,last_checked_at) VALUES ($1,$2,$3,$4,$5,$6,now())",
      [urlId, url, f.code, f.severity, f.auto_fixable, JSON.stringify(f.evidence || {})]);
  }
  for (const e of toResolve) {
    await pool.query("UPDATE seo_issues SET status='FIXED', resolved_at=now(), last_checked_at=now() WHERE id=$1", [e.id]);
  }
  if (toKeep.length) {
    await pool.query("UPDATE seo_issues SET last_checked_at=now() WHERE url_id=$1 AND code = ANY($2)", [urlId, toKeep.map(k => k.code)]);
  }
  return { opened: toOpen.length, resolved: toResolve.length, kept: toKeep.length };
}

async function applyScores(pool, urlId, scores, extra) {
  extra = extra || {};
  await pool.query(
    `UPDATE seo_urls SET technical_score=$2,content_score=$3,schema_score=$4,link_score=$5,health_score=$6,
       content_hash=COALESCE($7,content_hash), http_status=COALESCE($8,http_status),
       last_crawled_at=now(), last_validated_at=now(), lifecycle_state=COALESCE($9,lifecycle_state), updated_at=now()
     WHERE id=$1`,
    [urlId, scores.technical_score, scores.content_score, scores.schema_score, scores.link_score, scores.health_score,
     extra.contentHash || null, extra.httpStatus || null, extra.lifecycle || null]);
}

async function recordLinks(pool, sourceUrl, links, runId) {
  if (!links || !links.length) return 0;
  // refresh the outbound edges for this source
  await pool.query("DELETE FROM seo_links WHERE source_url=$1", [sourceUrl]);
  for (const l of links) {
    await pool.query("INSERT INTO seo_links(source_url,dest_url,anchor,rel,crawl_run) VALUES ($1,$2,$3,$4,$5)",
      [sourceUrl, l.href, (l.anchor || '').slice(0, 300), l.internal ? 'internal' : 'external', runId || null]);
  }
  return links.length;
}

/* ---------------------------- bounded fetch --------------------------- */
function fetchHtml(u, opts) {
  opts = opts || {};
  const maxBytes = opts.maxBytes || 1500000;
  const timeoutMs = opts.timeoutMs || 12000;
  const maxRedirects = opts.maxRedirects == null ? 4 : opts.maxRedirects;
  return new Promise(resolve => {
    let count = 0;
    const go = (target) => {
      let url; try { url = new URL(target); } catch (e) { return resolve({ status: 0, error: 'bad_url' }); }
      const lib = url.protocol === 'http:' ? http : https;
      const req = lib.request({
        method: 'GET', hostname: url.hostname, port: url.port || (url.protocol === 'http:' ? 80 : 443),
        path: url.pathname + url.search,
        headers: { 'User-Agent': opts.userAgent || 'GalaxySearchIntelligence/1.0 (+seo-self-audit)', 'Accept': 'text/html' }
      }, res => {
        const sc = res.statusCode;
        if (sc >= 300 && sc < 400 && res.headers.location && count < maxRedirects) {
          count++; res.resume();
          try { return go(new URL(res.headers.location, url).toString()); } catch (e) { return resolve({ status: sc, error: 'bad_redirect' }); }
        }
        let b = '', bytes = 0, aborted = false;
        res.on('data', d => { bytes += d.length; if (bytes > maxBytes) { aborted = true; req.destroy(); } else b += d; });
        res.on('end', () => resolve({ status: sc, body: b, truncated: aborted, finalUrl: url.toString() }));
      });
      req.on('error', e => resolve({ status: 0, error: String(e && e.message || e) }));
      req.setTimeout(timeoutMs, () => { req.destroy(); resolve({ status: 0, error: 'timeout' }); });
      req.end();
    };
    go(u);
  });
}

/* ------------------------------ the loop ----------------------------- */
// onPublish: fire when a page is published/changed. Registers + flags sitemap +
// returns the IndexNow queue (caller/loop submits). Emits events for subscribers.
async function onPublish(pool, evt, bus) {
  evt = evt || {};
  const reg = await registerUrl(pool, {
    url: evt.url, base: evt.base, entityType: evt.entityType || 'geo_page', entityId: evt.entityId,
    canonical: evt.canonical || evt.url, indexable: evt.indexable !== false,
    priority: evt.priority, lifecycle: 'PUBLISHED', contentHash: evt.contentHash
  });
  if (bus) await bus.emit('url.published', { url: evt.url, reg });
  return { registered: reg, indexnowQueue: (evt.indexable !== false && evt.url) ? [evt.url] : [] };
}

// sweep: the bounded background auditor. Picks the stalest indexable URLs, fetches
// (unless a page-provider is injected), inspects, scores, records issues + links.
// opts: { base, limit=40, concurrency=2, delayMs=400, allowCrawl, fetcher, now }
async function sweep(pool, opts) {
  opts = opts || {};
  if (typeof opts.allowCrawl === 'function' && !(await opts.allowCrawl())) {
    return { skipped: 'crawl_not_allowed', inspected: 0 };
  }
  const limit = Math.min(opts.limit || 40, 200);
  const concurrency = Math.max(1, Math.min(opts.concurrency || 2, 4));
  const fetcher = opts.fetcher || ((u) => fetchHtml(u, opts));

  const rows = (await pool.query(
    `SELECT id,url,normalized_url,canonical_url FROM seo_urls
     WHERE indexable IS TRUE
     ORDER BY last_crawled_at ASC NULLS FIRST, crawl_priority DESC NULLS LAST
     LIMIT $1`, [limit])).rows;
  if (!rows.length) return { inspected: 0, issues: { opened: 0, resolved: 0 }, urls: [] };

  const results = [];
  let agg = { opened: 0, resolved: 0, kept: 0 };
  const queue = rows.slice();
  async function worker() {
    while (queue.length) {
      const row = queue.shift();
      const res = await fetcher(row.url);
      if (!res || !res.body || res.status < 200 || res.status >= 400) {
        await pool.query("UPDATE seo_urls SET http_status=$2,last_crawled_at=now(),updated_at=now() WHERE id=$1",
          [row.id, (res && res.status) || 0]).catch(() => {});
        // a dead/again-moved URL is itself an issue
        await recordIssues(pool, row.id, row.url, [{ code: 'FETCH_FAILED', severity: 'HIGH', auto_fixable: false, evidence: { status: (res && res.status) || 0, error: res && res.error } }]).catch(() => {});
        results.push({ url: row.url, status: (res && res.status) || 0, failed: true });
      } else {
        const insp = inspectHtml(res.body, { url: row.url, base: opts.base || row.url, expectedCanonical: row.canonical_url || row.url });
        const scores = scoreFromInspection(insp);
        await applyScores(pool, row.id, scores, { contentHash: insp.signals.contentHash, httpStatus: res.status, lifecycle: 'VALIDATED' });
        const d = await recordIssues(pool, row.id, row.url, insp.issues);
        await recordLinks(pool, row.url, insp.signals.links, opts.runId).catch(() => {});
        agg.opened += d.opened; agg.resolved += d.resolved; agg.kept += d.kept;
        results.push({ url: row.url, status: res.status, health: scores.health_score, issues: insp.issues.length });
      }
      if (opts.delayMs) await new Promise(r => setTimeout(r, opts.delayMs));
    }
  }
  const workers = []; for (let i = 0; i < concurrency; i++) workers.push(worker());
  await Promise.all(workers);
  return { inspected: results.length, issues: agg, urls: results };
}

module.exports = {
  makeBus, normalizeUrl, inspectHtml, scoreFromInspection, diffIssues,
  registerUrl, recordIssues, applyScores, recordLinks, fetchHtml, onPublish, sweep
};
