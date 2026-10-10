'use strict';
/* Tablet fix: the header collapses to its compact form at <=760px, but the app bar shows at
   <=860px + touch tablets — so tablets (iPad Mini 768, iPad Pro, Surface) get the crowded desktop
   header and it overflows ("cutting"). Align the header-collapse breakpoint with the app model:
   <=860px, or any touch device <=1366px. Edits the single header-collapse media query in place
   (the one immediately before `.hd-in{height:auto`). Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_hdrbp.js <app.css path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

const marker = '.hd-in{height:auto';
const mi = s.indexOf(marker);
if (mi < 0) throw new Error('ANCHOR MISS: .hd-in{height:auto not found in app.css');
const before = s.slice(Math.max(0, mi - 160), mi);
if (before.indexOf('pointer:coarse') >= 0) { console.log('skip (already): header breakpoint already tablet-aware'); console.log('HDRBP PATCH OK'); process.exit(0); }

const mq = '@media(max-width:760px)';
const qi = s.lastIndexOf(mq, mi);
if (qi < 0 || (mi - qi) > 160) throw new Error('ANCHOR MISS: header-collapse @media(max-width:760px) not found before .hd-in');
s = s.slice(0, qi) + '@media(max-width:860px),(max-width:1366px) and (pointer:coarse)' + s.slice(qi + mq.length);

fs.writeFileSync(file, s);
console.log('patched: header collapses on tablets too (<=860px or touch <=1366px)');
console.log('HDRBP PATCH OK');
