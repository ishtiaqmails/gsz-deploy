'use strict';
/* Adds FAQPage structured data (schema.org) to every product page, built live from the real
   product FAQs, combined with the existing Product schema in a single @graph. This wins the
   expandable FAQ rich result on Google and is the content AI answer-engines quote. Self-aware:
   it renders from whatever FAQs the product currently has. routes/products.js. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_faqschema.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/products.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('_faqLd') >= 0) { console.log('skip (already): faq schema'); console.log('FAQSCHEMA OK'); process.exit(0); }

const FIND = 'const jsonLd = JSON.stringify(_ld)';
if (s.indexOf(FIND) < 0) throw new Error('ANCHOR MISS: jsonLd assembly');
const REPL =
  "const _faqLd = (faqs && faqs.length) ? { '@context': 'https://schema.org/', '@type': 'FAQPage', " +
  "mainEntity: faqs.map(function (f) { return { '@type': 'Question', name: f.q, acceptedAnswer: { '@type': 'Answer', text: f.a } }; }) } : null; " +
  "const jsonLd = JSON.stringify(_faqLd ? { '@context': 'https://schema.org/', '@graph': [_ld, _faqLd] } : _ld)";
s = s.replace(FIND, REPL);

fs.writeFileSync(file, s);
console.log('patched: product pages emit Product + FAQPage schema (@graph)');
console.log('FAQSCHEMA OK');
