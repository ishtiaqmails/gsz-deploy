'use strict';
/* Netflix code reader — NEW gzportal API. Two-step: resolve the account id by email
   (GET /accounts?email=), then read its classified codes (GET /accounts/:id/codes).
   Maps received_at -> date (what the UI/gate read), decodes HTML entities in `link`
   (the API sends &amp;-escaped URLs), and DROPS owner_only codes (account-takeover
   emails must never reach customers). 12s in-memory cache; fully fail-safe
   (unreachable / unauthorized / timeout -> {ok:false,emails:[]}). */
const https = require('https');
const http = require('http');
const { URL } = require('url');

const BASE = (process.env.NF_PORTAL_URL || 'https://app.galaxyzayron.store/api/v1').replace(/\/+$/, '');
const KEY = process.env.NF_READ_KEY || '';
const TTL = 12000;
const cache = new Map();

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

async function listForAccount(email, force) {
  email = String(email || '').trim();
  if (!email) return { ok: false, emails: [] };
  if (/@gsztest\.dev$/i.test(email)) {
    const _n = Date.now();
    return { ok: true, emails: [
      { type: 'signin_code', code: '428613', subject: 'Your Netflix sign-in code', date: new Date(_n - 2 * 60000).toISOString() },
      { type: 'household', link: 'https://www.netflix.com/account/travel/verify?demo=1', subject: 'Update your Netflix Household', date: new Date(_n - 40 * 60000).toISOString() },
      { type: 'password_reset', link: 'https://www.netflix.com/password?g=demo', subject: 'Complete your password reset request', date: new Date(_n - 60 * 60000).toISOString() }
    ] };
  }
  const k = 'nf:' + email.toLowerCase();
  if (!force) { const c = cache.get(k); if (c && c.exp > Date.now()) return c.val; }
  let val;
  const ar = await get('/accounts?email=' + encodeURIComponent(email));
  const acc = (ar.status === 200 && ar.json && ar.json.ok && ar.json.account) ? ar.json.account : null;
  if (!acc || acc.id == null) {
    val = { ok: false, emails: [], status: ar.status };
  } else {
    const cr = await get('/accounts/' + encodeURIComponent(acc.id) + '/codes');
    if (cr.status === 200 && cr.json && cr.json.ok) {
      const codes = Array.isArray(cr.json.codes) ? cr.json.codes : [];
      const emails = codes.filter(c => c && c.owner_only !== true).map(c => ({
        type: String(c.type || 'other'),
        code: c.code || '',
        link: c.link ? decodeEntities(c.link) : '',
        subject: c.subject || '',
        label: c.label || '',
        date: c.received_at || c.date || ''
      }));
      val = { ok: true, emails: emails };
    } else {
      val = { ok: false, emails: [], status: cr.status };
    }
  }
  cache.set(k, { val, exp: Date.now() + TTL });
  return val;
}
function configured() { return !!KEY; }

module.exports = { listForAccount, configured };
