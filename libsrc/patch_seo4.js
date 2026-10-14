'use strict';
/* SEO Batch 4 — enrich homepage Organization schema with sameAs (socials) + contactPoint (WhatsApp).
   Single-line anchor in server.js, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_seo4.js <ROOT>'); process.exit(1); }
const SV = path.join(ROOT, 'server.js');
let s = fs.readFileSync(SV, 'utf8');
if (s.indexOf("sameAs: ['https://instagram.com/galaxysubz'") >= 0) { console.log('skip (already): seo4'); process.exit(0); }
const find = "{ '@type': 'Organization', '@id': _base + '/#org', name: _sn, url: _base + '/', logo: _img, description: d.metaDescription },";
const i = s.indexOf(find);
if (i < 0) throw new Error('ANCHOR MISS: Organization ld');
if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: Organization ld');
const repl = "{ '@type': 'Organization', '@id': _base + '/#org', name: _sn, url: _base + '/', logo: _img, description: d.metaDescription, sameAs: ['https://instagram.com/galaxysubz', 'https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11'], contactPoint: [{ '@type': 'ContactPoint', contactType: 'customer support', url: 'https://wa.me/923141892712', availableLanguage: ['en', 'ur'] }] },";
fs.writeFileSync(SV, s.slice(0, i) + repl + s.slice(i + find.length));
console.log('patched: seo4 (Organization sameAs + contactPoint)');
