'use strict';
/* Bing Webmaster site verification meta tag (public code). Added to the shared head after the
   theme-color meta from SEO Batch 1. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_bingverify.js <ROOT>'); process.exit(1); }
const ST = path.join(ROOT, 'views/partials/store_top.ejs');
let s = fs.readFileSync(ST, 'utf8');
if (s.indexOf('msvalidate.01') >= 0) { console.log('skip (already): bing-verify'); process.exit(0); }
const anchor = '<meta name="theme-color" content="#0b1030">';
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: theme-color (deploy SEO Batch 1 first)');
const add = anchor + '\n<meta name="msvalidate.01" content="A8C78A0DA13D868A052A51738B141CFE">';
fs.writeFileSync(ST, s.slice(0, i) + add + s.slice(i + anchor.length));
console.log('patched: bing-verify');
