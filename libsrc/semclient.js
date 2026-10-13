'use strict';
/* Main-app client for the semantic sidecar (gsz-sem on 127.0.0.1:3910).
   Everything here is best-effort and never throws: if the service is slow or down, calls
   return null and the bot falls back to its keyword engine. Uses the plain http module
   (no fetch dependency) with hard timeouts. */
const http = require('http');
const kbmod = require('./supportkb');

const HOST = '127.0.0.1';
const PORT = Number(process.env.SEM_PORT || 3910);
let _lastSig = null, _indexing = false;

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

// Self-aware re-index: push the corpus whenever the catalog's content signature changes
// (any product / plan / price / FAQ / category edit), and only then — so nothing is
// re-embedded needlessly. The KB auto-refreshes on its own TTL, so edits propagate by
// themselves within a couple of minutes; markStale()/force make it immediate.
async function ensureIndexed(pool, opts) {
  opts = opts || {};
  if (_indexing) return;
  _indexing = true;
  try {
    const kb = await kbmod.get(pool, { force: !!opts.force });   // rebuilds if stale
    if (!opts.force && kb.sig === _lastSig) return;              // nothing changed since last push
    const h = await req('/health', null, 800);
    if (!h || !h.ready) return;                                  // sidecar not up yet
    const r = await req('/reindex', kbmod.corpus(kb), 90000);    // generous: let the embed finish so we mark success (no retry spiral)
    if (r && r.ok) _lastSig = kb.sig;
  } catch (e) { /* ignore */ } finally { _indexing = false; }
}

async function match(message) {
  const r = await req('/match', { message: String(message || '').slice(0, 512) }, 1500);
  return (r && r.ok) ? { product: r.product, faq: r.faq, intent: r.intent } : null;
}

function markStale() { _lastSig = null; }

module.exports = { ensureIndexed, match, markStale };
