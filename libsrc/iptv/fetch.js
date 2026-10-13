'use strict';
/* IPTV Library Engine — fetcher. Pulls the full library from a panel's Xtream Codes API.
   Self-contained (plain http/https), robust to timeouts and non-JSON. Returns raw arrays;
   cleaning/normalisation happens in clean.js. */
const http = require('http');
const https = require('https');
const { URL } = require('url');

// Xtream panels (and Cloudflare in front of them) commonly 403 any non-player User-Agent as
// anti-leech. Real IPTV apps send one of these, so we rotate through them on a 403/401 until the
// panel answers. Order = most widely whitelisted first.
const USER_AGENTS = [
  'IPTVSmartersPlayer',
  'VLC/3.0.20 LibVLC/3.0.20',
  'okhttp/4.9.3',
  'Lavf/58.76.100',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
];

function getOnce(rawUrl, ms, ua) {
  return new Promise((resolve) => {
    let u;
    try { u = new URL(rawUrl); } catch (e) { return resolve({ ok: false, status: 0, error: 'bad_url' }); }
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request(u, { method: 'GET', headers: { 'User-Agent': ua, 'Accept': '*/*', 'Connection': 'close' } }, (res) => {
      let s = '';
      res.on('data', d => { s += d; });
      res.on('end', () => {
        if (res.statusCode >= 300) return resolve({ ok: false, status: res.statusCode, error: 'http_' + res.statusCode });
        try { resolve({ ok: true, status: res.statusCode, data: JSON.parse(s) }); }
        catch (e) { resolve({ ok: false, status: res.statusCode, error: 'bad_json', sample: s.slice(0, 160) }); }
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
  if (!r.ok) return { ok: false, error: r.error, sample: r.sample };
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

module.exports = { info, fetchAll, api, winningUA: () => _goodUA, userAgents: USER_AGENTS };
