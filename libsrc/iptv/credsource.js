'use strict';
/* IPTV Library Engine — automatic credential source. Zero manual work, zero credit burn.
   The GSZ site NEVER touches the reseller DB (different server, API-key only) and NEVER
   destabilises the bot — it sources a read-only Xtream login through the existing gsz-api:

     1) ORDERS-FIRST (preferred, nothing generated): GET /api/panel-sample-creds/:sku returns the
        most recent delivered FAMILY line's {host,username,password}. Read-only, no credit, no trial.
        (Small new bot endpoint — until it exists this call 404s and we fall through to step 2.)
     2) FREE-TRIAL FALLBACK (already live): POST /api/generate-trial -> poll /api/trial-status.
        Runs through the bot's ban-safe web-trial queue (demo ticket = free, no bot restart).

   Either way we get username/password/DNS, log into the panel's Xtream API read-only (fetch.js),
   and pull the whole library. FAMILY ONLY is enforced twice: we only ever ask for family lines/
   trials here, and clean.js strips any adult entry regardless of source. Self-contained http. */
const http = require('http');
const https = require('https');
const fs = require('fs');
const { URL } = require('url');

// ---- config: gsz-api base + key, from env or /opt/gsz/.env (so the probe works standalone) ----
function loadEnv() {
  let base = process.env.GSZ_BOT_API_URL || '', key = process.env.GSZ_BOT_API_KEY || '';
  if ((!base || !key)) {
    for (const p of ['/opt/gsz/.env', '/opt/gsz-deploy/.env']) {
      try {
        const txt = fs.readFileSync(p, 'utf8');
        const mb = txt.match(/^\s*GSZ_BOT_API_URL\s*=\s*(.+)\s*$/m);
        const mk = txt.match(/^\s*GSZ_BOT_API_KEY\s*=\s*(.+)\s*$/m);
        if (!base && mb) base = mb[1].trim().replace(/^["']|["']$/g, '');
        if (!key && mk) key = mk[1].trim().replace(/^["']|["']$/g, '');
        if (base && key) break;
      } catch (e) {}
    }
  }
  return { base: base.replace(/\/+$/, ''), key };
}

function apiReq(method, path, body, ms) {
  const { base, key } = loadEnv();
  return new Promise((resolve) => {
    if (!base) return resolve({ ok: false, status: 0, error: 'no_api_url' });
    let u; try { u = new URL(base + path); } catch (e) { return resolve({ ok: false, status: 0, error: 'bad_url' }); }
    const lib = u.protocol === 'https:' ? https : http;
    const payload = body ? Buffer.from(JSON.stringify(body)) : null;
    const headers = { 'Accept': 'application/json', 'X-API-Key': key, 'User-Agent': 'IPTVLibraryEngine/1.0' };
    if (payload) { headers['Content-Type'] = 'application/json'; headers['Content-Length'] = payload.length; }
    const req = lib.request(u, { method, headers }, (res) => {
      let s = ''; res.on('data', d => { s += d; });
      res.on('end', () => {
        let data = null; try { data = JSON.parse(s); } catch (e) {}
        resolve({ ok: res.statusCode < 300, status: res.statusCode, data, raw: s.slice(0, 300) });
      });
    });
    req.on('error', (e) => resolve({ ok: false, status: 0, error: e.code || e.message }));
    req.setTimeout(ms || 20000, () => { try { req.destroy(); } catch (e) {} resolve({ ok: false, status: 0, error: 'timeout' }); });
    if (payload) req.write(payload);
    req.end();
  });
}

/* Pull host / username / password out of the bot's delivery-format message (any shape).
   The bot returns lines like "👤 Username: xxx", "🔑 Password: yyy", "🌐 DNS: http://host:port"
   (host/m3u fields are often null even when the DNS line is present — hence we parse the text). */
function parseCreds(src) {
  const text = typeof src === 'string' ? src : (src && (src.formatted || src.credentials || src.message || '')) || '';
  const fields = (src && typeof src === 'object') ? src : {};
  const grab = (re) => { const m = text.match(re); return m ? m[1].trim() : ''; };
  let username = (fields.username || fields.user || '') || grab(/(?:user\s*name|username|user)\s*[:：]\s*`?([^\s`<]+)/i);
  let password = (fields.password || fields.pass || '') || grab(/(?:pass\s*word|password|pass)\s*[:：]\s*`?([^\s`<]+)/i);
  let host = (fields.host || fields.dns || fields.url || fields.server || '') || grab(/(?:dns|host|server|url|portal)\s*[:：]\s*`?(https?:\/\/[^\s`<]+)/i) || grab(/(https?:\/\/[^\s`<]+?)(?:\/(?:get|player_api)\.php|\/c\/?|\s|$)/i);
  // strip any trailing path so fetch.js can append /player_api.php
  if (host) { const hm = host.match(/^(https?:\/\/[^/]+)/i); if (hm) host = hm[1]; }
  // if the only host we have came as "domain:port" without scheme
  if (!host) { const hp = grab(/\b((?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d{2,5})?)\b/i); if (hp) host = 'http://' + hp; }
  return { host, username, password, ok: !!(host && username && password) };
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// Tiny on-disk creds cache so repeat refreshes reuse a still-valid line instead of generating a
// fresh trial every time (free + ban-safe, but pointless churn). Trial creds live ~trial-hours;
// order creds are a real customer line, re-checked hourly. Cache is local + gitignored.
const CACHE = require('path').join(__dirname, '.creds-cache.json');
function readCache() { try { return JSON.parse(fs.readFileSync(CACHE, 'utf8')); } catch (e) { return {}; } }
function cacheGet(sku) {
  const c = readCache()[sku];
  if (c && c.host && c.username && c.password && c.expires > Date.now()) return c;
  return null;
}
function cachePut(sku, creds, ttlMs) {
  try { const all = readCache(); all[sku] = Object.assign({}, creds, { expires: Date.now() + ttlMs, cachedAt: Date.now() }); fs.writeFileSync(CACHE, JSON.stringify(all)); } catch (e) {}
}

/* Resolve a usable read-only Xtream login for a product sku.
   opts: { hours=24, trialTimeoutMs=120000, allowTrial=true }
   returns { ok, host, username, password, source:'order'|'trial', note } or { ok:false, error } */
async function resolve(sku, opts) {
  opts = opts || {};
  // 0) reuse a cached, still-valid line (unless caller forces fresh)
  if (!opts.fresh) { const cached = cacheGet(sku); if (cached) return Object.assign({ ok: true }, cached, { note: 'cached ' + cached.source }); }

  // 1) orders-first — a delivered FAMILY line, nothing generated, zero credit
  const o = await apiReq('GET', '/api/panel-sample-creds/' + encodeURIComponent(sku), null, 20000);
  if (o.ok && o.data) {
    const c = parseCreds(o.data.creds || o.data);
    if (c.ok) { const out = Object.assign(c, { source: 'order', note: 'recent delivered family line' }); cachePut(sku, out, 60 * 60 * 1000); return out; }
  }
  if (opts.allowTrial === false) return { ok: false, error: 'no_order_creds', detail: (o.status === 404 ? 'panel-sample-creds endpoint not deployed yet' : o.error || o.status) };

  // 2) free-trial fallback — ban-safe web-trial queue, demo ticket (free)
  const request_id = 'LIBENG-' + sku + '-' + Date.now().toString(36);
  const g = await apiReq('POST', '/api/generate-trial', { sku, hours: opts.hours || 24, type: 'family', customer_ref: 'library-engine', request_id }, 45000);
  if (!g.ok && g.status !== 409 /*idempotent re-post*/) return { ok: false, error: 'trial_request_failed', detail: g.error || g.status || g.raw };
  const rid = (g.data && (g.data.request_id || g.data.id)) || request_id;

  const trialTtl = Math.max(30 * 60 * 1000, (opts.hours || 24) * 3600 * 1000 - 30 * 60 * 1000); // trial life minus 30-min safety
  // some panels deliver inline on the POST already
  let c = parseCreds(g.data || {});
  if (c.ok) { const out = Object.assign(c, { source: 'trial', note: 'inline trial' }); cachePut(sku, out, trialTtl); return out; }

  const deadline = Date.now() + (opts.trialTimeoutMs || 120000);
  while (Date.now() < deadline) {
    await sleep(4000);
    const st = await apiReq('GET', '/api/trial-status/' + encodeURIComponent(rid), null, 15000);
    const d = st.data || {};
    const status = String(d.status || '').toLowerCase();
    c = parseCreds(d);
    if (c.ok) { const out = Object.assign(c, { source: 'trial', note: 'queued trial ready' }); cachePut(sku, out, trialTtl); return out; }
    if (status === 'failed' || status === 'error' || status === 'rejected') return { ok: false, error: 'trial_failed', detail: d.error || d.reason || status };
  }
  return { ok: false, error: 'trial_timeout', detail: 'no credentials within ' + ((opts.trialTimeoutMs || 120000) / 1000) + 's' };
}

module.exports = { resolve, parseCreds, apiReq, loadEnv };
