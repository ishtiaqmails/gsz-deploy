'use strict';
/* Main-app client for the semantic sidecar (gsz-sem on 127.0.0.1:3910).
   Everything here is best-effort and never throws: if the service is slow or down, calls
   return null and the bot falls back to its keyword engine. Uses the plain http module
   (no fetch dependency) with hard timeouts. */
const http = require('http');
const kbmod = require('./supportkb');

const HOST = '127.0.0.1';
const PORT = Number(process.env.SEM_PORT || 3910);
let _indexedAt = 0, _indexing = false;

function req(path, body, ms) {
  return new Promise(resolve => {
    const data = body ? JSON.stringify(body) : null;
    const r = http.request({ host: HOST, port: PORT, path, method: body ? 'POST' : 'GET',
      headers: body ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {} },
      res => { let s = ''; res.on('data', d => s += d); res.on('end', () => { try { resolve(JSON.parse(s)); } catch (e) { resolve(null); } }); });
    r.on('error', () => resolve(null));
    r.setTimeout(ms || 600, () => { try { r.destroy(); } catch (e) {} resolve(null); });
    if (data) r.write(data);
    r.end();
  });
}

// Push the current catalog+FAQ corpus to the sidecar. Cached ~10 min unless forced.
async function ensureIndexed(pool, opts) {
  opts = opts || {};
  const fresh = (Date.now() - _indexedAt) < 10 * 60 * 1000;
  if (_indexing || (fresh && !opts.force)) return;
  _indexing = true;
  try {
    const h = await req('/health', null, 500);
    if (!h || !h.ready) return;                              // service not up yet
    if (h.counts && h.counts.products > 0 && fresh && !opts.force) { _indexedAt = Date.now(); return; }
    const kb = await kbmod.get(pool, { force: !!opts.force });
    const r = await req('/reindex', kbmod.corpus(kb), 15000);
    if (r && r.ok) _indexedAt = Date.now();
  } catch (e) { /* ignore */ } finally { _indexing = false; }
}

async function match(message) {
  const r = await req('/match', { message: String(message || '').slice(0, 512) }, 600);
  return (r && r.ok) ? { product: r.product, faq: r.faq, intent: r.intent } : null;
}

function markStale() { _indexedAt = 0; }

module.exports = { ensureIndexed, match, markStale };
