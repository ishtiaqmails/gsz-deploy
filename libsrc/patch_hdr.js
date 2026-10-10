'use strict';
/* Mobile header fix (source edit in app.css): the mobile rule uses flex-wrap:wrap and the row of
   logo(150) + "IPTV Free Trial"(139) + WhatsApp(44) + menu(44) + gaps overflows 375px, so the logo
   drops to its own line (header ~172px tall). Fix WITHOUT hiding anything: slightly shrink the logo
   and the trial pill and right-align the controls so all four fit one row; search stays on its own
   row below. Injected inside the existing max-width:760 block. Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_hdr.js <app.css path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('gsz-hdr-fix') >= 0) { console.log('skip (already): header fix present'); console.log('HDR PATCH OK'); process.exit(0); }

const anchor = 'min-height:64px;gap:10px;flex-wrap:wrap';
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: mobile .hd-in rule not found in app.css');
const close = s.indexOf('}', i);
if (close < 0) throw new Error('ANCHOR MISS: closing brace of mobile .hd-in rule');

const inject = ' .brand{margin-right:auto} .brand img{height:32px} .hd-trial{padding:8px 11px;font-size:12px} /* gsz-hdr-fix */';
s = s.slice(0, close + 1) + inject + s.slice(close + 1);
fs.writeFileSync(file, s);
console.log('patched: mobile header — fit logo + trial + WhatsApp + menu on one row (search below)');
console.log('HDR PATCH OK');
