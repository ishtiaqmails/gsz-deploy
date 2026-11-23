#!/usr/bin/env bash
# stepZayronGszApi — add zayron's gsz-api client (lib/gszApi.js), a faithful port of GSZ's
# proven lib/botapi.js so zayron talks to the SAME bridge with the SAME key (one payment system).
# This only ADDS a file (nothing wired yet), so there's no restart and zero risk to the live site.
# Env it reads (copy from /opt/gsz/.env): GSZ_BOT_API_URL, GSZ_BOT_API_KEY.
set -e
Z=/opt/zayron
cd "$Z"

cat > lib/gszApi.js <<'GSZAPI'
'use strict';
/* lib/gszApi.js — zayron <-> reseller bot bridge (gsz-api).
   Ported from the GSZ lib/botapi.js client: same instance, same X-API-Key, core http/https
   only, safe when unconfigured. Env: GSZ_BOT_API_URL, GSZ_BOT_API_KEY (same as /opt/gsz/.env). */
const https = require('https');
const http = require('http');
const { URL } = require('url');

const TTL = { pay: 5, status: 4 };
const cache = new Map();
const cget = k => { const e = cache.get(k); return (e && e.exp > Date.now()) ? e.val : undefined; };
const cset = (k, v, ttl) => { cache.set(k, { val: v, exp: Date.now() + ttl * 1000 }); return v; };

function cfg() {
  return { base: (process.env.GSZ_BOT_API_URL || '').replace(/\/+$/, ''), key: process.env.GSZ_BOT_API_KEY || '' };
}
function configured() { const c = cfg(); return !!(c.base && c.key); }

function req(method, pathname, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const c = cfg();
    if (!c.base || !c.key) return reject(new Error('gsz_api_unconfigured'));
    let u; try { u = new URL(c.base + pathname); } catch (e) { return reject(new Error('bad_base_url')); }
    const lib = u.protocol === 'http:' ? http : https;
    const data = body ? Buffer.from(JSON.stringify(body)) : null;
    const opt = {
      method, hostname: u.hostname, port: u.port || (u.protocol === 'http:' ? 80 : 443),
      path: u.pathname + u.search,
      headers: Object.assign(
        { 'X-API-Key': c.key, 'Accept': 'application/json' },
        data ? { 'Content-Type': 'application/json', 'Content-Length': data.length } : {}
      )
    };
    const r = lib.request(opt, res => {
      let buf = ''; res.setEncoding('utf8');
      res.on('data', d => { buf += d; if (buf.length > 1e6) r.destroy(new Error('response_too_large')); });
      res.on('end', () => {
        let j = null; try { j = buf ? JSON.parse(buf) : {}; } catch (e) { j = { _raw: buf }; }
        if (res.statusCode >= 200 && res.statusCode < 300) return resolve(j);
        return reject(new Error('http_' + res.statusCode + (j && j.error ? ':' + j.error : '')));
      });
    });
    r.on('error', reject);
    r.setTimeout(timeoutMs || 8000, () => r.destroy(new Error('timeout')));
    if (data) r.write(data);
    r.end();
  });
}

// GET /api/pay-accounts -> { ok, accounts:[{key,method,label,currency,title,account,instructions,region}] }
async function getPayAccounts() {
  const hit = cget('pay'); if (hit !== undefined) return hit;
  const j = await req('GET', '/api/pay-accounts', null, 6000);
  return cset('pay', j, TTL.pay);
}
// POST /api/verify-claim -> { ok, result:'genuine'|'pending'|'fraud_consumed'|'lost_race', idempotent? }
function verifyClaim(payload) { return req('POST', '/api/verify-claim', payload, 30000); }
// GET /api/order-status/:ref
function orderStatus(ref) { return req('GET', '/api/order-status/' + encodeURIComponent(ref), null, 8000); }
// POST /api/submit-order
function submitOrder(payload) { return req('POST', '/api/submit-order', payload, 30000); }

module.exports = { configured, getPayAccounts, verifyClaim, orderStatus, submitOrder };
GSZAPI

node --check lib/gszApi.js || { echo "syntax error - removing"; rm -f lib/gszApi.js; exit 1; }
echo "DONE: lib/gszApi.js added (not wired yet — no restart needed)."
