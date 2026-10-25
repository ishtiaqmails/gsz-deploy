'use strict';
/* galaxytools.net — Netflix code reader, NEW gzportal API (https://app.galaxyzayron.store/api/v1).
   Two-step: GET /accounts?email= -> id, then GET /accounts/:id/codes. Auth: Authorization: Bearer.
   Maps received_at -> date, decodes HTML entities in `link`, drops owner_only (takeover) codes.
   Passes the portal `type` through unchanged (lib/netflixGate maps it to the store vocabulary).
   12s in-memory cache; fully fail-safe. Demo account testnetflix@galaxy.pk previews the panel. */
const https = require('https');
const http = require('http');
const { URL } = require('url');

const BASE = (process.env.NF_PORTAL_URL || 'https://app.galaxyzayron.store/api/v1').replace(/\/+$/, '');
const KEY = (process.env.NF_READ_KEY || '').trim();
const TTL = 12000;
const _cache = new Map();

function get(path) {
  return new Promise((resolve) => {
    try {
      const u = new URL(BASE + path);
      const lib = u.protocol === 'https:' ? https : http;
      const r = lib.request({
        hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + u.search, method: 'GET',
        headers: { 'Authorization': 'Bearer ' + KEY, 'Accept': 'application/json' }
      }, (res) => {
        let b = ''; res.setEncoding('utf8'); res.on('data', d => b += d);
        res.on('end', () => { let j = null; try { j = b ? JSON.parse(b) : null; } catch (e) { j = null; } resolve({ status: res.statusCode, json: j }); });
      });
      r.on('error', () => resolve({ status: 0, json: null }));
      r.setTimeout(8000, () => r.destroy());
      r.end();
    } catch (e) { resolve({ status: 0, json: null }); }
  });
}
function decodeEntities(s) {
  return String(s == null ? '' : s)
    .replace(/&amp;/g, '&').replace(/&#0*38;/g, '&').replace(/&#x0*26;/gi, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#0*39;/g, "'").replace(/&#x0*2f;/gi, '/');
}

async function listForAccount(accountEmail, force) {
  const email = String(accountEmail || '').trim();
  if (String(email).toLowerCase() === 'testnetflix@galaxy.pk') {
    const now = Date.now();
    return { ok: true, emails: [
      { type: 'signin_code', code: '428613', link: '', subject: 'Your Netflix sign-in code', from: 'info@account.netflix.com', date: new Date(now - 3 * 60000).toISOString() },
      { type: 'temporary_access', code: '771204', link: '', subject: 'Your temporary access code (travelling)', from: 'info@account.netflix.com', date: new Date(now - 11 * 60000).toISOString() },
      { type: 'household', code: '', link: 'https://www.netflix.com/account/update-primary-location?nftoken=DEMO', subject: 'Update your Netflix Household', from: 'info@account.netflix.com', date: new Date(now - 26 * 60000).toISOString() },
      { type: 'password_reset', code: '', link: 'https://www.netflix.com/password?g=DEMO', subject: 'Complete your password reset request', from: 'info@account.netflix.com', date: new Date(now - 42 * 60000).toISOString() }
    ] };
  }
  if (!email) return { ok: false, emails: [] };
  const k = email.toLowerCase();
  if (!force) { const c = _cache.get(k); if (c && (Date.now() - c.at) < TTL) return { ok: true, emails: c.emails, cached: true }; }

  const ar = await get('/accounts?email=' + encodeURIComponent(email));
  const acc = (ar.status === 200 && ar.json && ar.json.ok && ar.json.account) ? ar.json.account : null;
  if (!acc || acc.id == null) return { ok: false, emails: [], status: ar.status };
  const cr = await get('/accounts/' + encodeURIComponent(acc.id) + '/codes');
  if (!(cr.status === 200 && cr.json && cr.json.ok)) return { ok: false, emails: [], status: cr.status };
  const emails = (Array.isArray(cr.json.codes) ? cr.json.codes : [])
    .filter(c => c && c.owner_only !== true)
    .map(c => ({
      type: String(c.type || 'other'),
      code: c.code || '',
      link: c.link ? decodeEntities(c.link) : '',
      subject: c.subject || '',
      from: c.from || '',
      date: c.received_at || c.date || ''
    }));
  _cache.set(k, { at: Date.now(), emails: emails });
  return { ok: true, emails: emails };
}

function configured() { return !!KEY; }
module.exports = { listForAccount, configured };
