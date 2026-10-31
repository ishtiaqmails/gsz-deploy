'use strict';
/* lib/indexnow.js — IndexNow instant-indexing submitter (Bing / Yandex / Seznam / Naver).
 *
 * IndexNow pings participating engines the moment a URL is published or changes,
 * instead of waiting weeks for an organic crawl. It needs one thing from the owner:
 * a key (any 8-128 char hex-ish string) whose value is also served at
 *   https://<host>/<key>.txt
 * The engine hits that file to verify ownership, then trusts submissions.
 *
 * DORMANT BY DESIGN: with no key configured every entry point is a safe no-op that
 * returns {skipped:'no_key'} and writes nothing. Drop a key in and it activates.
 *
 * Pure, offline-testable:
 *   buildPayload({host,key,keyLocation,urls}) -> the JSON body
 *   keyFileContent(key)                        -> the text the /<key>.txt file must serve
 *   keyFromConfig(env)                         -> resolves a key from env/args, or null
 * Networked (only ever runs on the production host, never from the build box):
 *   submit(pool, opts) -> posts in batches, records seo_submissions, dedupes recent
 *
 * Dependency-free: uses node's https module directly.
 */
const https = require('https');
const { URL } = require('url');

const ENDPOINT = 'https://api.indexnow.org/indexnow';
const MAX_PER_REQUEST = 10000;   // protocol cap
const DEDUPE_HOURS = 6;          // don't re-ping the same URL within this window

function keyFromConfig(env) {
  env = env || process.env;
  return env.INDEXNOW_KEY || env.INDEX_NOW_KEY || null;
}
function keyFileContent(key) { return String(key || '').trim(); }
function keyLocationFor(host, key, explicit) {
  if (explicit) return explicit;
  if (!host || !key) return null;
  const h = /^https?:\/\//i.test(host) ? host.replace(/\/+$/, '') : 'https://' + host.replace(/\/+$/, '');
  return h + '/' + key + '.txt';
}
function hostOf(host) {
  if (!host) return null;
  try { return new URL(/^https?:\/\//i.test(host) ? host : 'https://' + host).host; }
  catch (e) { return String(host).replace(/^https?:\/\//i, '').replace(/\/.*$/, ''); }
}

function buildPayload(o) {
  o = o || {};
  const host = hostOf(o.host);
  return {
    host,
    key: o.key,
    keyLocation: o.keyLocation || keyLocationFor(o.host, o.key),
    urlList: (o.urls || []).slice(0, MAX_PER_REQUEST)
  };
}

function chunk(a, n) { const o = []; for (let i = 0; i < a.length; i += n) o.push(a.slice(i, i + n)); return o; }

// Low-level POST returning { status, body }. Never throws; resolves with an error shape.
function httpsPostJson(endpoint, bodyObj, timeoutMs) {
  return new Promise(resolve => {
    let u; try { u = new URL(endpoint); } catch (e) { return resolve({ status: 0, body: 'bad_endpoint' }); }
    const data = Buffer.from(JSON.stringify(bodyObj));
    const req = https.request({
      method: 'POST', hostname: u.hostname, port: u.port || 443, path: u.pathname + u.search,
      headers: { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': data.length }
    }, res => {
      let b = ''; res.on('data', d => { b += d; }); res.on('end', () => resolve({ status: res.statusCode, body: b }));
    });
    req.on('error', e => resolve({ status: 0, body: String(e && e.message || e) }));
    req.setTimeout(timeoutMs || 10000, () => { req.destroy(); resolve({ status: 0, body: 'timeout' }); });
    req.write(data); req.end();
  });
}

async function recentlySubmitted(pool, urls) {
  if (!pool || !urls.length) return new Set();
  try {
    const r = await pool.query(
      "SELECT DISTINCT url FROM seo_submissions WHERE engine='indexnow' AND status='ok' " +
      "AND submitted_at > now() - ($1 || ' hours')::interval AND url = ANY($2)",
      [String(DEDUPE_HOURS), urls]);
    return new Set(r.rows.map(x => x.url));
  } catch (e) { return new Set(); }
}
async function record(pool, url, status, response) {
  if (!pool) return;
  try {
    await pool.query(
      "INSERT INTO seo_submissions(url,engine,action,status,response) VALUES ($1,'indexnow','submit',$2,$3)",
      [url, status, JSON.stringify(response || {})]);
  } catch (e) { /* best-effort */ }
}

/* submit(pool, {
 *   host, key?, keyLocation?, urls[], endpoint?, poster?(testing), skipDedupe?
 * }) -> { skipped? , submitted, batches:[{count,status}], failed }
 */
async function submit(pool, opts) {
  opts = opts || {};
  const key = opts.key || keyFromConfig();
  if (!key) return { skipped: 'no_key', submitted: 0 };
  const host = opts.host;
  if (!host) return { skipped: 'no_host', submitted: 0 };
  let urls = Array.from(new Set((opts.urls || []).filter(Boolean)));
  if (!urls.length) return { skipped: 'no_urls', submitted: 0 };

  if (!opts.skipDedupe) {
    const recent = await recentlySubmitted(pool, urls);
    urls = urls.filter(u => !recent.has(u));
    if (!urls.length) return { skipped: 'all_recent', submitted: 0 };
  }

  const poster = opts.poster || httpsPostJson;   // injectable for tests
  const endpoint = opts.endpoint || ENDPOINT;
  const keyLocation = opts.keyLocation || keyLocationFor(host, key);
  const batches = []; let submitted = 0, failed = 0;

  for (const grp of chunk(urls, MAX_PER_REQUEST)) {
    const payload = buildPayload({ host, key, keyLocation, urls: grp });
    const res = await poster(endpoint, payload);
    const ok = res.status >= 200 && res.status < 300;
    // 200/202 = accepted; 400 bad request; 403 key not valid; 422 urls don't belong; 429 too many.
    const statusLabel = ok ? 'ok' : ('http_' + (res.status || 0));
    for (const u of grp) await record(pool, u, statusLabel, { status: res.status });
    batches.push({ count: grp.length, status: res.status });
    if (ok) submitted += grp.length; else failed += grp.length;
  }
  return { submitted, failed, batches };
}

module.exports = {
  buildPayload, keyFileContent, keyLocationFor, keyFromConfig, hostOf, submit,
  ENDPOINT, MAX_PER_REQUEST, DEDUPE_HOURS, _httpsPostJson: httpsPostJson, _chunk: chunk
};
