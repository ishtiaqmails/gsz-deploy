'use strict';
/* Accounts Portal client — NEW gzportal API (https://app.galaxyzayron.store/api/v1).
   Auth: Authorization: Bearer <NF_READ_KEY>. JSON in/out.
   Products/stock key off the portal's `old_id` (our stored per-plan id).
   Assign = create/find customer, then assign a free account.
   Fail-safe: every call returns {ok:false,...} on any error, never throws. */
const https = require('https');
const http = require('http');
const { URL } = require('url');

const BASE = (process.env.NF_PORTAL_URL || 'https://app.galaxyzayron.store/api/v1').replace(/\/+$/, '');
const KEY = process.env.NF_READ_KEY || '';

function call(method, path, bodyObj) {
  return new Promise((resolve) => {
    try {
      const u = new URL(BASE + path);
      const lib = u.protocol === 'https:' ? https : http;
      const data = bodyObj != null ? Buffer.from(JSON.stringify(bodyObj)) : null;
      const headers = { 'Authorization': 'Bearer ' + KEY, 'Accept': 'application/json' };
      if (data) { headers['Content-Type'] = 'application/json'; headers['Content-Length'] = data.length; }
      const r = lib.request({
        hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + u.search, method: method, headers: headers
      }, (res) => {
        let b = ''; res.setEncoding('utf8'); res.on('data', d => b += d);
        res.on('end', () => { let j = null; try { j = b ? JSON.parse(b) : null; } catch (e) { j = null; } resolve({ status: res.statusCode, json: j }); });
      });
      r.on('error', () => resolve({ status: 0, json: null }));
      r.setTimeout(20000, () => r.destroy());
      if (data) r.write(data);
      r.end();
    } catch (e) { resolve({ status: 0, json: null }); }
  });
}
const get = (p) => call('GET', p, null);
const post = (p, b) => call('POST', p, b || {});
function pidOf(p) { return p && (p.old_id != null ? p.old_id : p.id); }

// ---- products (12s cache) ----
let _pc = { t: 0, v: [] };
async function products(force) {
  if (!force && _pc.t > Date.now() - 12000 && _pc.v.length) return _pc.v;
  const r = await get('/products');
  let list = [];
  if (r.status === 200 && r.json) list = Array.isArray(r.json) ? r.json : (Array.isArray(r.json.products) ? r.json.products : []);
  if (list.length) _pc = { t: Date.now(), v: list };
  return list;
}

async function stock(productId) {
  if (productId == null || productId === '') return { ok: false, count: null };
  const list = await products();
  const hit = list.find(p => String(pidOf(p)) === String(productId) || String(p.id) === String(productId));
  if (hit) return { ok: true, count: Number(hit.free || 0) };
  const r = await get('/stock?product=' + encodeURIComponent(productId));
  if (r.status === 200 && r.json && r.json.ok) return { ok: true, count: Number(r.json.count || 0) };
  return { ok: false, count: null };
}

// ---- assign: POST /customers (idempotent) then POST /assign ----
async function assign(o) {
  o = o || {};
  const username = (String(o.buyerName || 'Customer').trim()) || 'Customer';
  const whatsapp = String(o.buyerWhatsApp || '').replace(/[^0-9]/g, '');
  const cust = await post('/customers', { username: username, whatsapp: whatsapp });
  if (!(cust.status >= 200 && cust.status < 300) || !cust.json || cust.json.ok === false) {
    return { ok: false, status: cust.status, error: (cust.json && cust.json.error) || ('customers_http_' + cust.status) };
  }
  const custUser = (cust.json.customer && cust.json.customer.username) || username;
  const custPass = cust.json.password || (cust.json.customer && cust.json.customer.password) || '';
  const r = await post('/assign', { product: o.productId, customer: custUser, days: o.days || 30 });
  if (r.status === 200 && r.json && r.json.ok && r.json.assigned) {
    const a = r.json.assigned;
    return {
      ok: true,
      assignedEmail: a.email || '',
      password: a.password || '',
      portalUrl: r.json.portal_url || BASE.replace(/\/api\/v1\/?$/, ''),
      customerUsername: custUser,
      customerPassword: custPass,
      instructions: a.instructions || '',
      country: a.country || '',
      expiresAt: a.expires_at || null,
      accountId: a.account_id || null
    };
  }
  return { ok: false, status: r.status, error: (r.json && r.json.error) || ('assign_http_' + r.status) };
}

function configured() { return !!KEY; }
module.exports = { products, stock, assign, configured };
