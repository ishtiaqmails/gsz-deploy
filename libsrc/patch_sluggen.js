'use strict';
/* #82 — new products get a clean name slug (no Date.now tail), made unique by a numeric
   suffix only on a real collision. routes/adminCatalog.js (model-save create path).
   Anchored on content only (no leading-whitespace dependency). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_sluggen.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*cleanSlug*/') >= 0) { console.log('skip (already): clean slug gen'); console.log('SLUGGEN OK'); process.exit(0); }

const FIND = "const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') + '-' + Date.now().toString(36);";
if (s.indexOf(FIND) < 0) throw new Error('ANCHOR MISS: new-product slug generator');
const REPL =
  "let slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || ('product-' + Date.now().toString(36)); /*cleanSlug*/\n" +
  "        { let _b = slug, _n = 1; while (((await c.query('SELECT 1 FROM products WHERE slug=$1', [slug])).rows || []).length) { _n++; slug = _b + '-' + _n; } }";
s = s.replace(FIND, REPL);

fs.writeFileSync(file, s);
console.log('patched: new-product slug = clean name slug (collision-safe)');
console.log('SLUGGEN OK');
