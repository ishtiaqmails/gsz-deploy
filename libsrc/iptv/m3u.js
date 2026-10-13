'use strict';
/* IPTV Library Engine — M3U source. Streams and parses an `#EXTM3U` playlist into the same
   shape fetchAll() returns, so the clean/store/display pipeline doesn't care which source was used.
   Streaming line-by-line: never holds the whole playlist in memory, so a multi-hundred-MB M3U with
   hundreds of thousands of entries stays light. Classifies each entry into live / vod / series by
   its group-title and stream-url shape, the same split the Xtream API gives us for free. */
const http = require('http');
const https = require('https');
const zlib = require('zlib');
const readline = require('readline');
const { URL } = require('url');
const proxy = require('./proxy');

const CHROME_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
function browserHeaders() {
  return {
    'User-Agent': CHROME_UA,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'none',
    'Upgrade-Insecure-Requests': '1'
  };
}

// Attributes on an #EXTINF line: key="value" pairs, then a trailing display name after the comma.
const ATTR = /([a-zA-Z0-9_-]+)="([^"]*)"/g;

function parseExtinf(line) {
  const out = { attrs: {}, name: '' };
  // The display name is after the comma that FOLLOWS the attribute block. A base64 data-URI logo
  // (tvg-logo="data:image/jpeg;base64,…") contains its own comma, so splitting on the first comma
  // grabs the blob. Split on the first comma AFTER the last attribute quote instead.
  const lastQuote = line.lastIndexOf('"');
  const comma = line.indexOf(',', lastQuote >= 0 ? lastQuote + 1 : 0);
  const head = comma >= 0 ? line.slice(0, comma) : line;
  out.name = comma >= 0 ? line.slice(comma + 1).trim() : '';
  let m;
  ATTR.lastIndex = 0;
  while ((m = ATTR.exec(head)) !== null) out.attrs[m[1].toLowerCase()] = m[2];
  // guard: if a name still looks like a base64 blob, fall back to tvg-name
  if (/^[A-Za-z0-9+/]{40,}={0,2}$/.test(out.name.replace(/\s+/g, '')) && out.attrs['tvg-name']) out.name = out.attrs['tvg-name'];
  return out;
}

// A VOD/series entry's URL ends in a file extension (…/movie.mkv); a live stream does not
// (…/12345 or …/12345.ts/.m3u8). Series episodes live under /series/ in Xtream M3U exports.
const VOD_EXT = /\.(mkv|mp4|avi|mov|m4v|flv|wmv|mpg|mpeg|webm)(\?|$)/i;
function classify(url, group) {
  const u = String(url || '');
  const g = String(group || '').toLowerCase();
  if (/\/series\//i.test(u) || /\bseries\b/.test(g)) return 'series';
  if (VOD_EXT.test(u) || /\/movie\//i.test(u) || /\b(vod|movie|film|cinema)\b/.test(g)) return 'vod';
  return 'live';
}

// "The Boys S01 E03" / "The Boys S1E3" -> { title:"The Boys", season:1, ep:3 }. Falls back to the
// whole name as the series title when no SxxEyy marker is present.
const SE = /^(.*?)[\s._-]*[sS](\d{1,2})[\s._-]*[eE](\d{1,3})\b/;
function seriesParts(name) {
  const m = String(name || '').match(SE);
  if (!m) return { title: String(name || '').trim(), season: null, ep: null };
  return { title: m[1].replace(/[._-]+/g, ' ').trim(), season: parseInt(m[2], 10), ep: parseInt(m[3], 10) };
}

let _proxy = process.env.IPTV_PROXY || process.env.ALL_PROXY || process.env.HTTP_PROXY || '';
function setProxy(p) { _proxy = p || ''; }

async function openStream(rawUrl, ms) {
  let u;
  try { u = new URL(rawUrl); } catch (e) { return { ok: false, error: 'bad_url' }; }
  const headers = browserHeaders();
  let lib = u.protocol === 'https:' ? https : http;
  let opts = { method: 'GET', headers };
  try {
    if (_proxy && proxy.isSocks(_proxy)) {
      const port = parseInt(u.port, 10) || (u.protocol === 'https:' ? 443 : 80);
      const sock = await proxy.socks5Connect(_proxy, u.hostname, port, ms);
      headers['Host'] = u.host;
      opts = { method: 'GET', headers, createConnection: () => sock, host: u.hostname, port, path: u.pathname + u.search };
      lib = http;
    } else if (_proxy && u.protocol === 'http:') {
      let px = new URL(_proxy);
      lib = px.protocol === 'https:' ? https : http;
      headers['Host'] = u.host;
      opts = { host: px.hostname, port: px.port || (px.protocol === 'https:' ? 443 : 80), method: 'GET', path: rawUrl, headers };
    } else {
      opts = u; opts.method = 'GET'; opts.headers = headers;
    }
  } catch (e) { return { ok: false, error: e.message || 'proxy_failed' }; }

  return new Promise((resolve) => {
    const req = lib.request(opts, (res) => {
      if (res.statusCode >= 300) { res.resume(); return resolve({ ok: false, error: 'http_' + res.statusCode }); }
      // decompress on the fly if the panel/Cloudflare gzipped the playlist
      const enc = (res.headers['content-encoding'] || '').toLowerCase();
      let stream = res;
      try {
        if (enc === 'gzip') stream = res.pipe(zlib.createGunzip());
        else if (enc === 'deflate') stream = res.pipe(zlib.createInflate());
        else if (enc === 'br') stream = res.pipe(zlib.createBrotliDecompress());
      } catch (e) {}
      resolve({ ok: true, stream });
    });
    req.on('error', (e) => resolve({ ok: false, error: e.code || e.message }));
    req.setTimeout(ms || 120000, () => { try { req.destroy(); } catch (e) {} resolve({ ok: false, error: 'timeout' }); });
    req.end();
  });
}

/* Parse an M3U from a URL (or a local path when it starts with "/" or "file:"). Returns the same
   { liveCats, vodCats, seriesCats, live, vod, series } shape as fetch.fetchAll so downstream code
   is source-agnostic. Series episodes are folded into one entry per show, with an episode count. */
async function fetchM3U(source, ms) {
  let input;
  if (/^https?:\/\//i.test(source)) {
    const r = await openStream(source, ms);
    if (!r.ok) return { ok: false, error: r.error };
    input = r.stream;
  } else {
    const fs = require('fs');
    const p = String(source).replace(/^file:\/\//, '');
    if (!fs.existsSync(p)) return { ok: false, error: 'file_not_found' };
    input = fs.createReadStream(p);
  }
  return parseFromInput(input);
}

// Parse an M3U already in memory (the phone POSTs the raw playlist text to the ingest endpoint).
async function parseM3UString(text) {
  const { Readable } = require('stream');
  return parseFromInput(Readable.from([String(text || '')]));
}

async function parseFromInput(input) {
  const live = [], vod = [];
  const seriesMap = new Map(); // title -> { name, category, episodes:Set("s-e"), logo }
  const liveCats = {}, vodCats = {}, seriesCats = {};
  let pending = null, count = 0;

  const rl = readline.createInterface({ input, crlfDelay: Infinity });
  for await (const raw of rl) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith('#EXTINF')) { pending = parseExtinf(line); continue; }
    if (line.startsWith('#')) continue;               // #EXTGRP etc. — ignore, group-title covers it
    if (!pending) continue;                            // a URL with no preceding #EXTINF
    const a = pending.attrs;
    const group = a['group-title'] || '';
    const name = pending.name || a['tvg-name'] || '';
    const logo = a['tvg-logo'] || '';
    const kind = classify(line, group);
    count++;

    if (kind === 'live') {
      if (group) liveCats[group] = group;
      live.push({ name, stream_icon: logo, category_name: group, epg: a['tvg-id'] || '' });
    } else if (kind === 'vod') {
      if (group) vodCats[group] = group;
      vod.push({ name, stream_icon: logo, category_name: group });
    } else {
      if (group) seriesCats[group] = group;
      const sp = seriesParts(name);
      const key = (sp.title || name).toLowerCase();
      let s = seriesMap.get(key);
      if (!s) { s = { name: sp.title || name, cover: logo, category_name: group, eps: new Set() }; seriesMap.set(key, s); }
      if (sp.season != null && sp.ep != null) s.eps.add(sp.season + '-' + sp.ep);
      else s.eps.add('x-' + s.eps.size);
    }
    pending = null;
  }

  const series = [...seriesMap.values()].map(s => ({ name: s.name, cover: s.cover, category_name: s.category_name, episode_count: s.eps.size }));
  return {
    ok: true, scanned: count,
    liveCats, vodCats, seriesCats,
    live, vod, series,
    errors: {}
  };
}

module.exports = { fetchM3U, parseM3UString, parseExtinf, classify, seriesParts, setProxy };
