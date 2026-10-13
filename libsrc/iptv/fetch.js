'use strict';
/* IPTV Library Engine — fetcher. Pulls the full library from a panel's Xtream Codes API.
   Self-contained (plain http/https), robust to timeouts and non-JSON. Returns raw arrays;
   cleaning/normalisation happens in clean.js. */
const http = require('http');
const https = require('https');
const zlib = require('zlib');
const { URL } = require('url');

// Full Chrome-like header set — Cloudflare's Browser Integrity Check 403s requests that don't look
// like a real browser (missing sec-ch-ua / sec-fetch / Accept-Language). Mirrors what the panel
// sees when it loads fine in a browser.
const CHROME_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
function browserHeaders(ua) {
  return {
    'User-Agent': ua,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'none',
    'sec-fetch-user': '?1',
    'Upgrade-Insecure-Requests': '1',
    'Connection': 'close'
  };
}
function decompress(buf, enc) {
  try {
    if (enc === 'gzip') return zlib.gunzipSync(buf).toString();
    if (enc === 'deflate') return zlib.inflateSync(buf).toString();
    if (enc === 'br') return zlib.brotliDecompressSync(buf).toString();
  } catch (e) {}
  return buf.toString();
}

// Xtream panels (and Cloudflare in front of them) commonly 403 any non-player User-Agent as
// anti-leech. Real IPTV apps send one of these, so we rotate through them on a 403/401 until the
// panel answers. Order = most widely whitelisted first.
const USER_AGENTS = [
  CHROME_UA,                       // full browser profile first — defeats Cloudflare Browser Integrity Check
  'IPTVSmartersPlayer',
  'VLC/3.0.20 LibVLC/3.0.20',
  'okhttp/4.9.3',
  'Lavf/58.76.100'
];

// Optional residential proxy (env or setProxy) — IPTV panels commonly 403 datacenter IPs, so the
// periodic catalog pull routes through a residential relay (e.g. the Tailscale phone, Every Proxy).
let _proxy = process.env.IPTV_PROXY || process.env.ALL_PROXY || process.env.HTTP_PROXY || '';
function setProxy(p) { _proxy = p || ''; }

function getOnce(rawUrl, ms, ua) {
  return new Promise((resolve) => {
    let u;
    try { u = new URL(rawUrl); } catch (e) { return resolve({ ok: false, status: 0, error: 'bad_url' }); }
    const headers = browserHeaders(ua);
    let lib, opts;
    if (_proxy && u.protocol === 'http:') {
      // absolute-URI form through an HTTP proxy (works for http targets, which these panels are)
      let px; try { px = new URL(_proxy); } catch (e) { return resolve({ ok: false, status: 0, error: 'bad_proxy' }); }
      lib = px.protocol === 'https:' ? https : http;
      headers['Host'] = u.host;
      opts = { host: px.hostname, port: px.port || (px.protocol === 'https:' ? 443 : 80), method: 'GET', path: rawUrl, headers };
    } else {
      lib = u.protocol === 'https:' ? https : http;
      opts = u; opts.method = 'GET'; opts.headers = headers;
    }
    const req = lib.request(opts, (res) => {
      const chunks = [];
      res.on('data', d => { chunks.push(d); });
      res.on('end', () => {
        const s = decompress(Buffer.concat(chunks), (res.headers['content-encoding'] || '').toLowerCase());
        const hdr = { server: res.headers['server'] || '', cfRay: res.headers['cf-ray'] || '', via: res.headers['via'] || '' };
        if (res.statusCode >= 300) return resolve({ ok: false, status: res.statusCode, error: 'http_' + res.statusCode, sample: s.replace(/\s+/g, ' ').slice(0, 220), hdr });
        try { resolve({ ok: true, status: res.statusCode, data: JSON.parse(s) }); }
        catch (e) { resolve({ ok: false, status: res.statusCode, error: 'bad_json', sample: s.slice(0, 160), hdr }); }
      });
    });
    req.on('error', (e) => resolve({ ok: false, status: 0, error: e.code || e.message }));
    req.setTimeout(ms || 45000, () => { try { req.destroy(); } catch (e) {} resolve({ ok: false, status: 0, error: 'timeout' }); });
    req.end();
  });
}

// Try the UA list; stop at the first that isn't an auth/leech block (403/401/429). Remembers the
// winning UA on module scope so the rest of the pulls skip straight to it.
let _goodUA = null;
async function getJson(rawUrl, ms) {
  const order = _goodUA ? [_goodUA, ...USER_AGENTS.filter(u => u !== _goodUA)] : USER_AGENTS;
  let last = null;
  for (const ua of order) {
    const r = await getOnce(rawUrl, ms, ua);
    last = r;
    if (r.ok) { _goodUA = ua; return r; }
    if (r.status && ![401, 403, 429].includes(r.status)) return r; // a real error (404/500/bad_json) — UA won't help
    if (r.error === 'bad_url') return r;
  }
  return last || { ok: false, error: 'unreachable' };
}

function api(host, user, pass, action, ms) {
  const base = String(host || '').replace(/\/+$/, '');
  const url = base + '/player_api.php?username=' + encodeURIComponent(user) + '&password=' + encodeURIComponent(pass) + '&action=' + action;
  return getJson(url, ms);
}

// Validate credentials + get account/server info (also the cheapest reachability check).
async function info(host, user, pass) {
  const base = String(host || '').replace(/\/+$/, '');
  const r = await getJson(base + '/player_api.php?username=' + encodeURIComponent(user) + '&password=' + encodeURIComponent(pass), 20000);
  if (!r.ok) return { ok: false, error: r.error, sample: r.sample, hdr: r.hdr };
  const d = r.data || {};
  const auth = d.user_info && (d.user_info.auth === 1 || d.user_info.auth === '1');
  return { ok: !!auth, user_info: d.user_info || null, server_info: d.server_info || null, error: auth ? null : 'auth_failed' };
}

// Pull the full library. Categories are fetched too so we can map category_id -> name.
async function fetchAll(host, user, pass) {
  const [liveCat, vodCat, serCat, live, vod, series] = await Promise.all([
    api(host, user, pass, 'get_live_categories'),
    api(host, user, pass, 'get_vod_categories'),
    api(host, user, pass, 'get_series_categories'),
    api(host, user, pass, 'get_live_streams'),
    api(host, user, pass, 'get_vod_streams'),
    api(host, user, pass, 'get_series')
  ]);
  const arr = r => (r && r.ok && Array.isArray(r.data)) ? r.data : [];
  const catMap = rows => { const m = {}; rows.forEach(c => { if (c && c.category_id != null) m[String(c.category_id)] = c.category_name || ''; }); return m; };
  return {
    liveCats: catMap(arr(liveCat)), vodCats: catMap(arr(vodCat)), seriesCats: catMap(arr(serCat)),
    live: arr(live), vod: arr(vod), series: arr(series),
    errors: { live: live && live.error, vod: vod && vod.error, series: series && series.error }
  };
}

module.exports = { info, fetchAll, api, setProxy, winningUA: () => _goodUA, userAgents: USER_AGENTS };
