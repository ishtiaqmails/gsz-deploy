'use strict';
/* lib/search_console.js — Google Search Console + Bing Webmaster metrics sync.
 *
 * DORMANT until credentials exist. With none it returns {skipped:'no_credentials'}
 * and does nothing. It never blocks startup and never touches the live site; it
 * only fills seo_search_metrics so the engine can prioritise real-performing URLs.
 *
 * Activate by setting either:
 *   GSC_SA_JSON  = <service-account JSON>  (+ GSC_SITE_URL = sc-domain:galaxyzayron.store or https URL)
 *   BING_API_KEY = <Bing Webmaster API key> (+ BING_SITE_URL)
 *
 * Pure / offline-testable:
 *   credentials(env)                 -> { gsc?, bing? } | null
 *   buildGscRequest(opts)            -> Search Analytics query body
 *   normalizeGscRow(row, dims, site) -> seo_search_metrics row
 *   jwtClaim(sa, scope, now)         -> the GSC OAuth2 JWT claim set
 *   signJwt(sa, claim)               -> signed RS256 assertion (node crypto)
 * Networked (injectable poster/fetcher; only runs on prod):
 *   syncGsc(pool, opts)  /  syncBing(pool, opts)  /  upsertMetrics(pool, rows)
 */
const https = require('https');
const crypto = require('crypto');
const { URL } = require('url');

/* ----------------------------- credentials ----------------------------- */
function credentials(env) {
  env = env || process.env;
  const out = {};
  if (env.GSC_SA_JSON) {
    try { out.gsc = { sa: JSON.parse(env.GSC_SA_JSON), site: env.GSC_SITE_URL || null }; }
    catch (e) { /* malformed -> stays dormant */ }
  }
  if (env.BING_API_KEY) out.bing = { key: env.BING_API_KEY, site: env.BING_SITE_URL || null };
  return (out.gsc || out.bing) ? out : null;
}

/* -------------------------------- GSC ---------------------------------- */
function b64url(buf) { return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); }

function jwtClaim(sa, scope, now) {
  now = now || Math.floor(Date.now() / 1000);
  return {
    iss: sa.client_email,
    scope: scope || 'https://www.googleapis.com/auth/webmasters.readonly',
    aud: sa.token_uri || 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600
  };
}
function signJwt(sa, claim) {
  const header = { alg: 'RS256', typ: 'JWT' };
  const signingInput = b64url(JSON.stringify(header)) + '.' + b64url(JSON.stringify(claim));
  const sig = crypto.createSign('RSA-SHA256').update(signingInput).sign(sa.private_key);
  return signingInput + '.' + b64url(sig);
}

function buildGscRequest(opts) {
  opts = opts || {};
  const end = opts.endDate || isoDate(daysAgo(2));   // GSC data lags ~2 days
  const start = opts.startDate || isoDate(daysAgo(30));
  return {
    startDate: start, endDate: end,
    dimensions: opts.dimensions || ['page', 'query', 'country', 'device'],
    rowLimit: Math.min(opts.rowLimit || 5000, 25000),
    startRow: opts.startRow || 0,
    type: opts.searchType || 'web'
  };
}
function normalizeGscRow(row, dims, site) {
  // GSC returns keys[] aligned to dimensions.
  const k = row.keys || [];
  const get = name => { const i = (dims || []).indexOf(name); return i >= 0 ? k[i] : null; };
  const dateDim = get('date');
  return {
    url: get('page') || site || null,
    query: get('query') || null,
    engine: 'google',
    country: (get('country') || null),
    device: (get('device') || null),
    date: dateDim || null,          // when date not a dimension, caller passes endDate
    clicks: row.clicks || 0,
    impressions: row.impressions || 0,
    ctr: row.ctr != null ? Number(row.ctr) : null,
    position: row.position != null ? Number(row.position) : null
  };
}

async function getGscToken(sa, poster) {
  const claim = jwtClaim(sa);
  const assertion = signJwt(sa, claim);
  const body = 'grant_type=' + encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer') +
    '&assertion=' + encodeURIComponent(assertion);
  const res = await (poster || httpsPost)(sa.token_uri || 'https://oauth2.googleapis.com/token',
    body, { 'Content-Type': 'application/x-www-form-urlencoded' });
  try { const j = JSON.parse(res.body); return j.access_token || null; } catch (e) { return null; }
}

async function syncGsc(pool, opts) {
  opts = opts || {};
  const creds = opts.gsc || (credentials() && credentials().gsc);
  if (!creds || !creds.sa || !creds.site) return { skipped: 'no_credentials', engine: 'google' };
  const poster = opts.poster || httpsPost;
  const token = opts.token || await getGscToken(creds.sa, poster);
  if (!token) return { skipped: 'auth_failed', engine: 'google' };

  const reqBody = buildGscRequest(opts);
  const endpoint = 'https://searchconsole.googleapis.com/webmasters/v3/sites/' +
    encodeURIComponent(creds.site) + '/searchAnalytics/query';
  const res = await poster(endpoint, JSON.stringify(reqBody),
    { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token });
  let rows = [];
  try { rows = (JSON.parse(res.body).rows) || []; } catch (e) { return { skipped: 'bad_response', engine: 'google', status: res.status }; }

  const dims = reqBody.dimensions;
  const norm = rows.map(r => {
    const n = normalizeGscRow(r, dims, creds.site);
    if (!n.date) n.date = reqBody.endDate;     // bucket to endDate when date isn't a dimension
    return n;
  });
  const n = await upsertMetrics(pool, norm);
  return { engine: 'google', fetched: rows.length, upserted: n };
}

/* -------------------------------- Bing --------------------------------- */
async function syncBing(pool, opts) {
  opts = opts || {};
  const creds = opts.bing || (credentials() && credentials().bing);
  if (!creds || !creds.key || !creds.site) return { skipped: 'no_credentials', engine: 'bing' };
  const poster = opts.poster || httpsGet;
  const endpoint = 'https://ssl.bing.com/webmaster/api.svc/json/GetQueryStats?apikey=' +
    encodeURIComponent(creds.key) + '&siteUrl=' + encodeURIComponent(creds.site);
  const res = await poster(endpoint);
  let rows = [];
  try { rows = (JSON.parse(res.body).d) || []; } catch (e) { return { skipped: 'bad_response', engine: 'bing', status: res.status }; }
  const norm = rows.map(r => ({
    url: creds.site, query: r.Query || null, engine: 'bing', country: null, device: null,
    date: bingDate(r.Date), clicks: r.Clicks || 0, impressions: r.Impressions || 0,
    ctr: r.Impressions ? (r.Clicks || 0) / r.Impressions : null, position: r.AvgImpressionPosition || null
  }));
  const n = await upsertMetrics(pool, norm);
  return { engine: 'bing', fetched: rows.length, upserted: n };
}
function bingDate(d) {
  if (!d) return null;
  const m = String(d).match(/\/Date\((\d+)\)\//); // Bing's /Date(ms)/ format
  if (m) return isoDate(new Date(Number(m[1])));
  try { return isoDate(new Date(d)); } catch (e) { return null; }
}

/* ------------------------------- upsert -------------------------------- */
async function upsertMetrics(pool, rows) {
  if (!pool || !rows || !rows.length) return 0;
  let n = 0;
  for (const r of rows) {
    if (!r.date) continue;
    try {
      await pool.query(
        `INSERT INTO seo_search_metrics(url,query,engine,country,device,date,clicks,impressions,ctr,position,synced_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,now())
         ON CONFLICT (url,query,engine,country,device,date) DO UPDATE SET
           clicks=EXCLUDED.clicks, impressions=EXCLUDED.impressions,
           ctr=EXCLUDED.ctr, position=EXCLUDED.position, synced_at=now()`,
        [r.url, r.query || '', r.engine, r.country || '', r.device || '', r.date,
         r.clicks || 0, r.impressions || 0, r.ctr, r.position]);
      n++;
    } catch (e) { /* skip bad row */ }
  }
  return n;
}

/* ------------------------------ helpers -------------------------------- */
function daysAgo(n) { const d = new Date(); d.setUTCDate(d.getUTCDate() - n); return d; }
function isoDate(d) { try { return new Date(d).toISOString().slice(0, 10); } catch (e) { return null; } }

function httpsReq(method, endpoint, body, headers) {
  return new Promise(resolve => {
    let u; try { u = new URL(endpoint); } catch (e) { return resolve({ status: 0, body: '' }); }
    const data = body ? Buffer.from(body) : null;
    const h = Object.assign({}, headers || {});
    if (data) h['Content-Length'] = data.length;
    const req = https.request({ method, hostname: u.hostname, port: u.port || 443, path: u.pathname + u.search, headers: h },
      res => { let b = ''; res.on('data', d => b += d); res.on('end', () => resolve({ status: res.statusCode, body: b })); });
    req.on('error', () => resolve({ status: 0, body: '' }));
    req.setTimeout(20000, () => { req.destroy(); resolve({ status: 0, body: '' }); });
    if (data) req.write(data); req.end();
  });
}
function httpsPost(endpoint, body, headers) { return httpsReq('POST', endpoint, body, headers); }
function httpsGet(endpoint, _b, headers) { return httpsReq('GET', endpoint, null, headers); }

module.exports = {
  credentials, buildGscRequest, normalizeGscRow, jwtClaim, signJwt,
  syncGsc, syncBing, upsertMetrics, _httpsPost: httpsPost, _httpsGet: httpsGet, _isoDate: isoDate
};
