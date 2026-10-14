'use strict';
/* SEO Batch 3 — server.js:
   - 301 redirect www.* -> non-www (one canonical host)
   - IndexNow key file served at /<key>.txt
   Inserted just before the /static middleware. Single-line anchor, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_seo3.js <ROOT>'); process.exit(1); }
const SV = path.join(ROOT, 'server.js');

let s = fs.readFileSync(SV, 'utf8');
if (s.indexOf("require('./lib/indexnow')") >= 0) { console.log('skip (already): seo3'); process.exit(0); }
const anchor = "app.use('/static', express.static(path.join(__dirname, 'public'), { maxAge: '7d' }));";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: static mount');
if (s.indexOf(anchor, i + anchor.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: static mount');
const block =
  "// SEO: canonical host — 301 www.* -> non-www\n" +
  "app.use(function (req, res, next) { const h = String(req.headers.host || ''); if (/^www\\./i.test(h)) return res.redirect(301, 'https://' + h.replace(/^www\\./i, '') + (req.originalUrl || '/')); next(); });\n" +
  "// SEO: IndexNow key file at /<key>.txt (hex only, never clashes with robots/llms/ads)\n" +
  "const indexnow = require('./lib/indexnow');\n" +
  "app.get(/^\\/([a-f0-9]{16,64})\\.txt$/i, async function (req, res) { try { const k = await indexnow.getKey(pool); if (k && String(req.params[0]).toLowerCase() === k) return res.type('text/plain').send(k); } catch (e) {} res.status(404).end(); });\n";
fs.writeFileSync(SV, s.slice(0, i) + block + anchor + s.slice(i + anchor.length));
console.log('patched: seo3 (www redirect + indexnow key route)');
