'use strict';
/* IPTV Library Engine — fetcher. Pulls the full library from a panel's Xtream Codes API.
   Self-contained (plain http/https), robust to timeouts and non-JSON. Returns raw arrays;
   cleaning/normalisation happens in clean.js. */
const http = require('http');
const https = require('https');
const { URL } = require('url');

function getJson(rawUrl, ms) {
  return new Promise((resolve) => {
    let u;
    try { u = new URL(rawUrl); } catch (e) { return resolve({ ok: false, error: 'bad_url' }); }
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request(u, { method: 'GET', headers: { 'User-Agent': 'IPTVLibraryEngine/1.0', 'Accept': 'application/json' } }, (res) => {
      let s = '';
      res.on('data', d => { s += d; });
      res.on('end', () => {
        if (res.statusCode >= 300) return resolve({ ok: false, error: 'http_' + res.statusCode });
        try { resolve({ ok: true, data: JSON.parse(s) }); }
        catch (e) { resolve({ ok: false, error: 'bad_json', sample: s.slice(0, 160) }); }
      });
    });
    req.on('error', (e) => resolve({ ok: false, error: e.code || e.message }));
    req.setTimeout(ms || 45000, () => { try { req.destroy(); } catch (e) {} resolve({ ok: false, error: 'timeout' }); });
    req.end();
  });
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

module.exports = { info, fetchAll, api };
