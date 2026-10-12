'use strict';
/* #82 — product route honours old-slug 301 redirects. When /product/:slug has no live product,
   consult cs_redirects for an old->new mapping and 301 there before showing notfound, so links
   that were already shared keep working after the slug cleanup. routes/products.js. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodredirect.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/products.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*prodRedirect*/') >= 0) { console.log('skip (already): product redirect'); console.log('PRODREDIRECT OK'); process.exit(0); }

const FIND = "      if (!prow) return res.status(404).render('notfound', { what: 'product' });";
if (s.indexOf(FIND) < 0) throw new Error('ANCHOR MISS: product 404 branch');
const REPL =
  "      if (!prow) { /*prodRedirect*/\n" +
  "        try {\n" +
  "          const rd = (await pool.query('SELECT to_path, code FROM cs_redirects WHERE from_path=$1', ['/product/' + req.params.slug])).rows[0];\n" +
  "          if (rd && rd.to_path) return res.redirect(rd.code || 301, rd.to_path);\n" +
  "        } catch (e) {}\n" +
  "        return res.status(404).render('notfound', { what: 'product' });\n" +
  "      }";
s = s.replace(FIND, REPL);

fs.writeFileSync(file, s);
console.log('patched: /product/:slug 301s old slugs via cs_redirects');
console.log('PRODREDIRECT OK');
