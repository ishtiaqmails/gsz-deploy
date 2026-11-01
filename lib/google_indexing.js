'use strict';
/* lib/google_indexing.js — push URLs to Google's Indexing API (instant "crawl this" signal).
 * Credentials: a Google service-account JSON stored in wa_settings key='google_sa_json'.
 * No external deps — signs the OAuth2 JWT with Node's crypto. Fail-safe: never throws, and is a
 * no-op until a key is saved. Google's daily quota is ~200 URLs, so callers batch accordingly.
 *
 * NOTE: Google officially supports this API for JobPosting/BroadcastEvent pages; for general
 * pages it is unofficial — it often prompts a crawl but indexing is never guaranteed. The
 * reliable path for general pages stays the sitemap + Search Console (already in place). */
const https = require('https');
const crypto = require('crypto');

let _tok = null, _exp = 0, _tokFor = null;

async function getSA(pool) {
  try {
    const r = (await pool.query("SELECT value FROM wa_settings WHERE key='google_sa_json'")).rows[0];
    if (!r || !r.value) return null;
    const sa = JSON.parse(r.value);
    if (sa && sa.client_email && sa.private_key) return sa;
    return null;
  } catch (e) { return null; }
}

function b64url(s) { return Buffer.from(s).toString('base64').replace(/=+$/g, '').replace(/\+/g, '-').replace(/\//g, '_'); }

function httpsPost(host, path, body, headers) {
  return new Promise(function (resolve) {
    try {
      const req = https.request({ host: host, path: path, method: 'POST', timeout: 9000, headers: Object.assign({ 'Content-Length': Buffer.byteLength(body) }, headers) },
        function (res) { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve({ status: res.statusCode, body: d })); });
      req.on('error', e => resolve({ status: 0, error: e.message }));
      req.on('timeout', () => { req.destroy(); resolve({ status: 0, error: 'timeout' }); });
      req.write(body); req.end();
    } catch (e) { resolve({ status: 0, error: e.message }); }
  });
}

async function getToken(sa) {
  if (_tok && _tokFor === sa.client_email && Date.now() < _exp - 60000) return _tok;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(JSON.stringify({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/indexing', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 }));
  const unsigned = header + '.' + claim;
  const signer = crypto.createSign('RSA-SHA256'); signer.update(unsigned); signer.end();
  const sig = signer.sign(sa.private_key).toString('base64').replace(/=+$/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const jwt = unsigned + '.' + sig;
  const body = 'grant_type=' + encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer') + '&assertion=' + encodeURIComponent(jwt);
  const r = await httpsPost('oauth2.googleapis.com', '/token', body, { 'Content-Type': 'application/x-www-form-urlencoded' });
  let j = {}; try { j = JSON.parse(r.body || '{}'); } catch (e) {}
  if (!j.access_token) throw new Error('token failed: ' + String(r.body || r.error || '').slice(0, 160));
  _tok = j.access_token; _exp = Date.now() + (j.expires_in || 3600) * 1000; _tokFor = sa.client_email;
  return _tok;
}

async function notifyOne(token, url, type) {
  return httpsPost('indexing.googleapis.com', '/v3/urlNotifications:publish',
    JSON.stringify({ url: url, type: type || 'URL_UPDATED' }),
    { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token });
}

// notify(pool, urls, type) — push up to ~200 URLs. Fail-safe; {ok,submitted,failed} or {ok:false,skip}.
async function notify(pool, urls, type) {
  try {
    const sa = await getSA(pool);
    if (!sa) return { ok: false, skip: 'not configured' };
    if (!Array.isArray(urls)) urls = [urls];
    urls = urls.filter(Boolean).slice(0, 200);
    if (!urls.length) return { ok: false, skip: 'no urls' };
    const token = await getToken(sa);
    let ok = 0, fail = 0, lastErr = '';
    for (const u of urls) { try { const r = await notifyOne(token, u, type); if (r.status >= 200 && r.status < 300) ok++; else { fail++; lastErr = String(r.body || r.error || r.status).slice(0, 160); } } catch (e) { fail++; lastErr = e.message; } }
    return { ok: true, submitted: ok, failed: fail, lastErr: fail ? lastErr : '' };
  } catch (e) { return { ok: false, error: e.message }; }
}

// notifyRecent(pool, base, limit) — newest indexable URLs (blogs + geo), within the daily quota.
const TYPE_PREFIX = { article: 'blog', news: 'news', guide: 'guides', tutorial: 'tutorials', review: 'reviews', comparison: 'comparisons', buying_guide: 'buying-guides', troubleshooting: 'troubleshooting', faq: 'knowledge', knowledge: 'knowledge' };
async function notifyRecent(pool, base, limit) {
  try {
    const sa = await getSA(pool); if (!sa) return { ok: false, skip: 'not configured' };
    const b = String(base || '').replace(/\/+$/, ''); if (!b) return { ok: false, skip: 'no base' };
    limit = Math.min(Math.max(parseInt(limit, 10) || 180, 1), 200);
    const items = [];
    try { (await pool.query("SELECT type,slug,COALESCE(updated_at,published_at,created_at) lm FROM cs_posts WHERE status='published' ORDER BY lm DESC LIMIT $1", [limit])).rows.forEach(p => items.push({ url: b + '/' + (TYPE_PREFIX[p.type] || 'blog') + '/' + p.slug, lm: p.lm })); } catch (e) {}
    try { (await pool.query("SELECT slug, COALESCE(published_at,updated_at) lm FROM geo_pages WHERE status='PUBLISHED' AND indexing_status='INDEX' ORDER BY lm DESC LIMIT $1", [limit])).rows.forEach(g => items.push({ url: b + g.slug, lm: g.lm })); } catch (e) {}
    items.sort((a, b2) => new Date(b2.lm || 0) - new Date(a.lm || 0));
    const urls = []; const seen = {};
    for (const it of items) { if (!seen[it.url]) { seen[it.url] = 1; urls.push(it.url); } if (urls.length >= limit) break; }
    return await notify(pool, urls, 'URL_UPDATED');
  } catch (e) { return { ok: false, error: e.message }; }
}

// status(pool) — for the admin page (never exposes the private key)
async function status(pool) {
  const sa = await getSA(pool);
  return sa ? { configured: true, client_email: sa.client_email, project_id: sa.project_id || '' } : { configured: false };
}

module.exports = { notify, notifyRecent, status, getSA, getToken };
